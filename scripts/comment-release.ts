import { Octokit } from "@octokit/rest";

/**
 * Comment on linked issues when a release is created
 *
 * Required environment variables:
 * - VERSION: The version tag of the release
 * - ISSUES: Comma-separated list of issue numbers
 * - GITHUB_TOKEN: GitHub token for authentication
 * - GITHUB_REPOSITORY: Repository in format "owner/repo"
 */
async function main() {
  const version = process.env.VERSION;
  const issues = process.env.ISSUES;
  const token = process.env.GITHUB_TOKEN;
  const repository = process.env.GITHUB_REPOSITORY;

  if (!version) {
    throw new Error("VERSION environment variable is not set");
  }

  if (!issues) {
    console.log("No linked issues found");
    return;
  }

  if (!token) {
    throw new Error("GITHUB_TOKEN environment variable is not set");
  }

  if (!repository) {
    throw new Error("GITHUB_REPOSITORY environment variable is not set");
  }

  const [owner, repo] = repository.split('/');
  if (!owner || !repo) {
    throw new Error(`Invalid GITHUB_REPOSITORY format: ${repository}`);
  }

  const octokit = new Octokit({ auth: token });

  const tagUrl = `https://github.com/${owner}/${repo}/releases/tag/${version}`;
  const commentBody = `Release created: [${version}](${tagUrl})`;

  const issueNumbers = issues
    .split(',')
    .map(s => Number(s.trim()))
    .filter(Boolean);

  console.log(`Found linked issues: ${issueNumbers}`);

  // Comment on each linked issue
  for (const issueNumber of issueNumbers) {
    console.log(`Commenting on issue #${issueNumber}`);
    await octokit.rest.issues.createComment({
      owner,
      repo,
      issue_number: issueNumber,
      body: commentBody
    });
  }

  console.log(`Successfully commented on ${issueNumbers.length} issue(s)`);
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
