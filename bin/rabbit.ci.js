#!/usr/bin/env node
'use strict';

const { spawnSync } = require('node:child_process');
const { existsSync, readdirSync, readFileSync, renameSync, writeFileSync, mkdirSync } = require('node:fs');
const { basename, join, relative, resolve } = require('node:path');
const YAML = require('yaml');

const RESOLUTION_VERSION = 'udx.dev/rabbit.ci/repo/v1';
const RESOLUTION_RELATIVE_PATH = '.rabbit/repo.yaml';

function usage() {
  return [
    'Usage: rabbit.ci [--json|--yaml]',
    '',
    'Generate the Rabbit CI repository resolution for the current repository.',
    '',
    '  rabbit.ci         Write .rabbit/repo.yaml and print a short summary.',
    '  rabbit.ci --json  Print the resolution as JSON without writing a file.',
    '  rabbit.ci --yaml  Print the resolution as YAML without writing a file.'
  ].join('\n');
}

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
}

function command(commandName, args, options = {}) {
  const result = spawnSync(commandName, args, {
    cwd: options.cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  });
  if (result.error || result.status !== 0) return null;
  return result.stdout;
}

function git(root, args) {
  const output = command('git', ['-C', root, ...args]);
  return output === null ? '' : output.trim();
}

function repositoryRoot() {
  const root = command('git', ['rev-parse', '--show-toplevel'], { cwd: process.cwd() });
  return root === null ? '' : root.trim();
}

function githubSlug(remote) {
  const match = remote.match(/^(?:git@github\.com:|ssh:\/\/git@github\.com\/|https?:\/\/github\.com\/)([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+?)(?:\.git)?$/);
  return match ? match[1] : '';
}

function githubApi(pathname) {
  const output = command('gh', ['api', '-X', 'GET', pathname]);
  if (output === null) return null;
  try {
    return JSON.parse(output);
  } catch {
    return null;
  }
}

function localBranches(root) {
  return git(root, ['for-each-ref', 'refs/remotes/origin', '--format=%(refname:short)'])
    .split('\n')
    .map((branch) => branch.replace(/^origin\//, ''))
    .filter((branch) => branch && branch !== 'HEAD');
}

function unique(values) {
  return [...new Set(values)];
}

function names(response, field) {
  return (response?.[field] || []).map((entry) => entry.name).filter(Boolean);
}

function withoutDescriptions(value) {
  if (Array.isArray(value)) return value.map(withoutDescriptions);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value)
        .filter(([key]) => key !== 'description')
        .map(([key, child]) => [String(key), withoutDescriptions(child)])
    );
  }
  return value;
}

function normalizedTriggers(document) {
  const triggers = document.on ?? document.true ?? {};
  if (typeof triggers === 'string') return { [triggers]: {} };
  if (Array.isArray(triggers)) return Object.fromEntries(triggers.map((trigger) => [String(trigger), {}]));
  if (!triggers || typeof triggers !== 'object') return {};
  return Object.fromEntries(
    Object.entries(triggers).map(([trigger, config]) => [
      String(trigger), config === null ? {} : withoutDescriptions(config)
    ])
  );
}

function workflowFiles(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true })
    .flatMap((entry) => {
      const path = join(directory, entry.name);
      if (entry.isDirectory()) return workflowFiles(path);
      return /\.ya?ml$/i.test(entry.name) ? [path] : [];
    })
    .sort();
}

function resolveWorkflows(root) {
  return workflowFiles(join(root, '.github', 'workflows')).map((file) => {
    let document;
    try {
      document = YAML.parse(readFileSync(file, 'utf8')) || {};
    } catch (error) {
      throw new Error(`cannot parse workflow ${relative(root, file)}: ${error.message}`);
    }
    const workflow = {
      path: relative(root, file).split('\\').join('/'),
      triggers: normalizedTriggers(document)
    };
    if (Object.hasOwn(document, 'permissions')) workflow.permissions = withoutDescriptions(document.permissions);
    return workflow;
  });
}

function branchRules(rules) {
  if (!Array.isArray(rules)) return {};
  return rules.reduce((result, rule) => {
    const parameters = rule.parameters || {};
    if (rule.type === 'deletion') result.allow_deletions = false;
    if (rule.type === 'non_fast_forward') result.allow_force_pushes = false;
    if (rule.type === 'pull_request') {
      result.pull_request = {
        approvals: parameters.required_approving_review_count ?? 0,
        code_owner_review: parameters.require_code_owner_review ?? false,
        stale_reviews: parameters.dismiss_stale_reviews_on_push ?? false,
        last_push_approval: parameters.require_last_push_approval ?? false,
        conversation_resolution: parameters.required_review_thread_resolution ?? false,
        merge_methods: parameters.allowed_merge_methods ?? []
      };
    }
    if (rule.type === 'copilot_code_review') {
      result.copilot_review = {
        on_push: parameters.review_on_push ?? false,
        drafts: parameters.review_draft_pull_requests ?? false
      };
    }
    return result;
  }, {});
}

function defaultEnvironment(inherited) {
  return {
    name: 'default',
    branches: ['*'],
    approvals: [],
    wait_minutes: 0,
    admin_bypass: true,
    secrets: inherited.secrets,
    variables: inherited.variables
  };
}

function resolveEnvironment(slug, environment, protectedBranches, inherited) {
  const encoded = encodeURIComponent(environment);
  const details = githubApi(`repos/${slug}/environments/${encoded}`) || {};
  const policy = details.deployment_branch_policy || {};
  let branches = ['*'];
  if (policy.custom_branch_policies) {
    const policies = githubApi(`repos/${slug}/environments/${encoded}/deployment-branch-policies`) || {};
    branches = (policies.branch_policies || []).map((entry) => entry.name).filter(Boolean);
  } else if (policy.protected_branches) {
    branches = protectedBranches;
  }
  const reviewers = (details.protection_rules || [])
    .filter((rule) => rule.type === 'required_reviewers')
    .flatMap((rule) => rule.reviewers || [])
    .map((reviewer) => ({ type: reviewer.type ?? reviewer.reviewer?.type ?? 'user', id: reviewer.id ?? reviewer.reviewer?.id }))
    .filter((reviewer) => reviewer.id !== undefined && reviewer.id !== null);
  const timer = (details.protection_rules || []).find((rule) => rule.type === 'wait_timer');
  const secrets = githubApi(`repos/${slug}/environments/${encoded}/secrets`) || {};
  const variables = githubApi(`repos/${slug}/environments/${encoded}/variables`) || {};
  return {
    name: environment,
    branches,
    approvals: reviewers,
    wait_minutes: timer?.wait_timer ?? timer?.wait_timer_minutes ?? 0,
    admin_bypass: details.can_admins_bypass ?? false,
    secrets: unique([...inherited.secrets, ...names(secrets, 'secrets')]),
    variables: unique([...inherited.variables, ...names(variables, 'variables')])
  };
}

function resolveRepository(root) {
  const remote = git(root, ['config', '--get', 'remote.origin.url']);
  const slug = githubSlug(remote);
  const owner = slug ? slug.split('/')[0] : '';
  let defaultBranch = git(root, ['symbolic-ref', '--short', 'refs/remotes/origin/HEAD']).replace(/^origin\//, '');
  if (!defaultBranch) defaultBranch = git(root, ['branch', '--show-current']);
  if (!defaultBranch) defaultBranch = 'unknown';

  const metadata = slug ? githubApi(`repos/${slug}`) : null;
  if (metadata?.default_branch) defaultBranch = metadata.default_branch;

  let observedBranches = [];
  let protectedBranches = [];
  if (metadata && slug) {
    const branches = githubApi(`repos/${slug}/branches?per_page=100`) || [];
    if (Array.isArray(branches)) {
      observedBranches = branches.map((branch) => branch.name).filter(Boolean);
      protectedBranches = branches.filter((branch) => branch.protected).map((branch) => branch.name);
    }
  }
  const branches = unique(observedBranches.length ? observedBranches : localBranches(root));
  if (!branches.length && defaultBranch !== 'unknown') branches.push(defaultBranch);

  const resolvedBranches = branches.map((name) => ({
    name,
    rules: slug && metadata ? branchRules(githubApi(`repos/${slug}/rules/branches/${encodeURIComponent(name)}`) || []) : {}
  }));
  const inherited = slug && metadata
    ? {
        secrets: unique([
          ...names(githubApi(`repos/${slug}/actions/organization-secrets?per_page=100`), 'secrets'),
          ...names(githubApi(`repos/${slug}/actions/secrets?per_page=100`), 'secrets')
        ]),
        variables: unique([
          ...names(githubApi(`repos/${slug}/actions/organization-variables?per_page=100`), 'variables'),
          ...names(githubApi(`repos/${slug}/actions/variables?per_page=100`), 'variables')
        ])
      }
    : { secrets: [], variables: [] };
  const environmentResponse = slug && metadata
    ? githubApi(`repos/${slug}/environments?per_page=100`)
    : null;
  const environmentNames = names(environmentResponse, 'environments');
  const environments = environmentResponse
    ? environmentNames.length
      ? environmentNames.map((environment) => resolveEnvironment(slug, environment, protectedBranches, inherited))
      : [defaultEnvironment(inherited)]
    : !slug
      ? [defaultEnvironment(inherited)]
      : [];

  return {
    kind: 'repo',
    version: RESOLUTION_VERSION,
    repository: owner ? { name: basename(root), owner, default_branch: defaultBranch } : { name: basename(root), default_branch: defaultBranch },
    branches: resolvedBranches,
    environments,
    workflows: resolveWorkflows(root)
  };
}

function writeResolution(root, resolution) {
  const file = join(root, RESOLUTION_RELATIVE_PATH);
  mkdirSync(join(root, '.rabbit'), { recursive: true });
  const temporary = `${file}.tmp.${process.pid}`;
  writeFileSync(temporary, YAML.stringify(resolution));
  renameSync(temporary, file);
}

function main() {
  const args = process.argv.slice(2);
  const format = args.length === 0 ? 'text' : args.length === 1 ? args[0] : null;
  if (!['text', '--json', '--yaml'].includes(format)) {
    fail(usage());
    return;
  }
  const root = repositoryRoot();
  if (!root) {
    fail(`not a Git repository: ${resolve('.')}`);
    return;
  }
  let resolution;
  try {
    resolution = resolveRepository(root);
  } catch (error) {
    fail(error.message);
    return;
  }
  if (format === '--json') {
    process.stdout.write(`${JSON.stringify(resolution, null, 2)}\n`);
    return;
  }
  if (format === '--yaml') {
    process.stdout.write(YAML.stringify(resolution));
    return;
  }
  writeResolution(root, resolution);
  process.stdout.write([
    'rabbit.ci',
    `  resolution: ${RESOLUTION_RELATIVE_PATH}`,
    `  repository: ${resolution.repository.name}`,
    `  branches: ${resolution.branches.length}`,
    `  environments: ${resolution.environments.length}`,
    `  workflows: ${resolution.workflows.length}`
  ].join('\n') + '\n');
}

main();
