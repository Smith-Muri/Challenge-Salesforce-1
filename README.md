# Salesforce DX Project

Salesforce DX is a development approach that brings source-driven development, team collaboration, and continuous integration to the Salesforce Platform. Instead of working directly in an org through a web browser, you work with metadata as source files in a local DX project, track changes in version control, and deploy through automated processes.

This project template gets you started with the tools and structure you need to build Salesforce applications using source control, scratch orgs, and the Salesforce CLI.

# Challenge Salesforce 1

## Objective

When a Case changes from a status other than `Reopened` to `Reopened`, notify its owner only when the related Account explicitly allows communications.

## Business Rules

- The transition to `Reopened` is required.
- An Account is required and `Account.Email_Communications__c` must be `true`.
- A Case owner must be a User. Queue owners are intentionally ignored because this challenge has no queue recipient policy.
- The owner is always the recipient. The executing user is never used as a fallback.
- The optional Email Template has DeveloperName `Case_Reopened_Notification`.
- If the template is unavailable, Custom Labels provide the subject and plain-text body.
- Cases that fail any rule are ignored without sending email.

## Architecture

```text
Case
	-> CaseTrigger
	-> CaseTriggerHandler
	-> Account eligibility
	-> User owner resolution
	-> Email construction
	-> Messaging.sendEmail()
```

The trigger is only an entry point. The handler identifies eligible transitions once, queries Accounts and Users in bulk, and makes one bulk email invocation.

## Security

`CaseTriggerHandler` uses `with sharing`. Account eligibility is queried with explicit `WITH SYSTEM_MODE` because the business opt-in field must be readable for the decision even when a profile does not expose it; record sharing still applies through the class sharing mode. Owner Users are resolved with `WITH USER_MODE` so recipient access is respected. The custom field must be included in the deploying permission model. Missing Account authorization produces no email.

## Bulkification

The handler uses Sets for Account and User IDs and Maps for resolution. There is no SOQL or DML inside a loop. It iterates the trigger records once to identify transitions, then iterates only `casesToNotify` to construct messages. Messages are grouped by User owner so one owner receives at most one message per transaction, avoiding Salesforce's individual-email limit while still sending through one `Messaging.sendEmail()` call.

## Email Configuration

The Apex supports two deployment modes:

1. Preferred: deploy an Email Template with DeveloperName `Case_Reopened_Notification`, configured for Case merge fields.
2. Fallback: if that template is absent, the handler uses `Case_Reopened_Email_Subject` and `Case_Reopened_Email_Body` Custom Labels and addresses the owner email explicitly.

The template is not currently versioned in this repository because no EmailTemplate metadata exists in the source. Create it manually or add its metadata before deployment when template content is required. In either mode, `SaveAsActivity` is false.

## Testing

`CaseTriggerTest` covers:

- Reopened with Account opt-in and owner recipient.
- Email construction, subject, body, recipient, and activity setting.
- Already Reopened and non-Reopened transitions.
- Account opt-out and missing Account.
- Queue owner behavior.
- 200 mixed Cases with only 100 authorized notifications.
- Multiple Case owners receiving their own messages.

Run local project checks with `npm install`, `npm run prettier:verify`, and `npm run lint`. Apex tests require an authorized Salesforce org:

```bash
sf project deploy start --source-dir force-app --target-org YOUR_ORG --test-level RunLocalTests
```

## Deployment

Deploy the `force-app` package, including:

- `CaseTrigger` and `CaseTriggerHandler`.
- `CaseTriggerTest`.
- `Account.Email_Communications__c`.
- Custom Labels used by the fallback email.
- An Email Template with DeveloperName `Case_Reopened_Notification` when template rendering is desired.

The scratch definition is in `config/project-scratch-def.json`. No org IDs, credentials, or secrets are stored in this repository.

## CI/CD

`.github/workflows/validate.yml` runs dependency installation, Prettier verification, and lint. Salesforce validation runs only when the repository secret `SF_TARGET_USERNAME` is configured; authentication must be supplied by the repository's Salesforce CI setup. The workflow does not deploy automatically to production.
