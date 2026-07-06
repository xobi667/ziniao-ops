# Operations workflows

Use this reference when the user asks for store operations beyond opening a single page, such as daily checks, full store summaries, ad reviews, order checks, customer-service risk checks, or reports.

Machine-readable workflow definitions live in `references/ops-workflows.json`.

## Workflow model

Each workflow has:

- `id`: stable command value for scripts.
- `phrases`: natural-language triggers.
- `views`: ordered store modules to open through `open-store.ps1`.
- `required_metrics`: metrics Codex should try to read from visible pages or user-provided exports.
- `questions`: analysis questions the final report should answer.

Current workflow coverage includes overall dashboard, ads, orders, products, inventory, traffic, finance, reviews, logistics, returns, customer service, compliance, creative assets, and marketing activities.

## Execution rules

1. Generate a task plan with `scripts\new-ops-task.ps1`.
2. Open the first required view through `open-store.ps1`.
3. Use visual navigation to move through the remaining views.
4. Record only visible metrics or explicitly provided local data.
5. Generate a report with `scripts\new-ops-report.ps1`.
6. If the user asks to send it to Feishu, use `scripts\send-ops-report-lark.ps1` or the available Feishu/Lark IM tool.

For batch work, create the checklist first with `scripts\new-ops-batch.ps1`; do not silently operate many stores without the employee understanding which stores will be opened.

## Safety

All workflows are read-only by default. Stop before any action that changes seller state, spends money, changes ads, refunds orders, publishes products, modifies inventory, edits settings, or sends messages to customers.
