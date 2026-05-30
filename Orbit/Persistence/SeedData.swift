import Foundation
import SwiftData

enum SeedData {
    /// Seeds all workspaces, projects, labels and issues on first launch.
    /// Idempotent: skips entirely if any workspace already exists.
    static func ensureSeed(_ context: ModelContext) -> Project? {
        let count = (try? context.fetchCount(FetchDescriptor<Workspace>())) ?? 0
        guard count == 0 else {
            let all = (try? context.fetch(FetchDescriptor<Workspace>())) ?? []
            return all.first?.unwrappedProjects.first
        }
        seedAll(context)
        return firstProject(context)
    }

    // MARK: - Private

    private static func firstProject(_ context: ModelContext) -> Project? {
        (try? context.fetch(FetchDescriptor<Workspace>()))?.first?.unwrappedProjects.first
    }

    private static func seedAll(_ context: ModelContext) {
        // ── Workspace: Stephen Scott Johnson ─────────────────────────────────
        let ssj = makeWorkspace("Stephen Scott Johnson", context: context)
        let labelGHL      = makeLabel("GHL",      hex: "#F5A623", workspace: ssj, context: context)
        let labelApp      = makeLabel("App",      hex: "#5E9EFF", workspace: ssj, context: context)
        let labelSupabase = makeLabel("Supabase", hex: "#56CF8F", workspace: ssj, context: context)
        let labelOpenAI   = makeLabel("OpenAI",   hex: "#A865C9", workspace: ssj, context: context)

        let projSSJ = makeProject("General", workspace: ssj, context: context)

        makeIssue(
            title: "Averiguar forma de prevenir gasto completo de créditos en OpenAI",
            details: "Investigar límites de gasto, rate limits, y maneras de configurar alertas o caps en la API de OpenAI para evitar sorpresas en la factura.",
            status: .backlog,
            priority: .high,
            project: projSSJ,
            labels: [labelOpenAI],
            context: context
        )
        makeIssue(
            title: "Métricas en dashboard",
            details: "Definir y agregar las métricas clave que deben aparecer en el dashboard principal de la aplicación.",
            status: .backlog,
            priority: .medium,
            project: projSSJ,
            labels: [labelApp],
            context: context
        )
        _ = labelGHL; _ = labelSupabase  // created, available for future use

        // ── Workspace: FlexSpace Logistics ───────────────────────────────────
        let fsl = makeWorkspace("FlexSpace Logistics", context: context)
        let labelAC         = makeLabel("AmazonConnect", hex: "#57C4E8", workspace: fsl, context: context)
        let labelSF         = makeLabel("Salesforce",    hex: "#5E9EFF", workspace: fsl, context: context)
        let labelN8n        = makeLabel("n8n",           hex: "#E8415B", workspace: fsl, context: context)
        let labelGH         = makeLabel("GitHub",        hex: "#6E7278", workspace: fsl, context: context)
        let labelVercel     = makeLabel("Vercel",        hex: "#4DBCB0", workspace: fsl, context: context)

        let projFSL = makeProject("Lauren & Pierre — Voice Agent Improvements", workspace: fsl, context: context)

        makeIssue(
            title: "01 · Warm Transfer — Qualified Leads During Business Hours",
            details: """
            When either agent (Lauren/Pierre) identifies a qualified lead during business hours \
            (Mon–Fri 8:00am–6:59pm EST), transfer the call in real time to 1-833-787-3084.

            • Add transfer_call tool in RetellAI for both agents
            • Update prompt logic: detect business hours + lead qualification criteria
            • Handoff script: "Let me connect you with one of our specialists. One moment please."
            • Fallback: if transfer fails → close normally and log lead in Salesforce
            • Amazon Connect workflow review (complexity TBD based on current AC setup)
            """,
            status: .inProgress,
            priority: .urgent,
            project: projFSL,
            labels: [labelAC, labelSF],
            context: context
        )
        makeIssue(
            title: "02 · Call Filtering — Package / Delivery Wrong Numbers",
            details: """
            Lauren detects package tracking / delivery-related calls early and redirects politely, \
            without creating a Salesforce lead.

            • Early keyword detection before call type identification
            • Keywords: "package", "delivery", "tracking", "order status", "shipment", "parcel"
            • Response: inform caller they've reached the wrong number, close gracefully
            • Add "Wrong Number" to call_type enum in post_call_analysis_data
            • n8n: if call_type = Wrong Number → skip Salesforce lead creation
            """,
            status: .todo,
            priority: .medium,
            project: projFSL,
            labels: [labelN8n, labelSF],
            context: context
        )
        makeIssue(
            title: "03 · Missed Calls — Lead Upsert by Phone Number in Salesforce",
            details: """
            When an agent speaks with a caller who already has a Salesforce lead (matched by phone), \
            update the existing record instead of creating a duplicate.

            • n8n: change from "always create" to lookup-first upsert
            • Step 1: GET lead in Salesforce by Phone = user_number
            • Step 2: If found → PATCH with captured data + set status to "Open - Not Contacted"
            • Step 3: If not found → POST (create new lead, existing behavior)
            • Amazon Connect: review current missed call lead creation flow
            """,
            status: .todo,
            priority: .high,
            project: projFSL,
            labels: [labelN8n, labelSF, labelAC],
            context: context
        )
        makeIssue(
            title: "04 · Unqualified Lead Flagging in Salesforce",
            details: """
            When an agent determines a caller is not a legitimate lead, update the existing Salesforce \
            record with "Unqualified" status and a reason note.

            • Add 2 new variables to post_call_analysis_data: is_qualified (Yes/No) and disqualification_reason
            • Prompt update: agent captures reason for disqualification during conversation
            • n8n: if is_qualified = No → lookup lead by phone → PATCH Status: "Unqualified" + note
            • Shares phone lookup infrastructure with Item 03
            """,
            status: .backlog,
            priority: .medium,
            project: projFSL,
            labels: [labelN8n, labelSF],
            context: context
        )
        makeIssue(
            title: "05 · Partial Lead Capture — Leads Without Full Details",
            details: """
            When Lauren speaks with a real prospect who doesn't provide all details (e.g. no company \
            name), still capture whatever is available and update Salesforce accordingly.

            • Prompt update: name + phone is sufficient to log — do not stall or drop the lead
            • n8n: submit to Salesforce even when non-critical fields are missing
            """,
            status: .backlog,
            priority: .medium,
            project: projFSL,
            labels: [labelN8n, labelSF],
            context: context
        )
        makeIssue(
            title: "06 · Email Recording Improvements",
            details: """
            Both agents confirm email addresses in two parts and include a retry fallback. \
            Backend normalizes common dictation errors before saving to Salesforce.

            • Prompt update: confirm email part by part (username + domain separately)
            • Fallback after 2 failed attempts: "No problem, our team will confirm your email when they reach out"
            • n8n normalization: "at"→@, "dot"→., "dash"→-, "underscore"→_, lowercase + trim
            """,
            status: .backlog,
            priority: .low,
            project: projFSL,
            labels: [labelN8n, labelSF],
            context: context
        )
        makeIssue(
            title: "07 · GitHub & Vercel Account Migration",
            details: """
            Move the existing codebase and deployment configuration from the Sidetool account \
            to FlexSpace's own accounts, ensuring full ownership.

            • Transfer GitHub repositories to FlexSpace organization or designated account
            • Migrate Vercel projects and update environment variables
            • Verify deployments post-migration
            """,
            status: .backlog,
            priority: .medium,
            project: projFSL,
            labels: [labelGH, labelVercel],
            context: context
        )

        // ── Empty workspaces ──────────────────────────────────────────────────
        _ = makeWorkspace("Langfuse",        context: context)
        _ = makeWorkspace("BlueJay",         context: context)
        _ = makeWorkspace("Amazon Connect",  context: context)
        _ = makeWorkspace("Salesforce",      context: context)

        try? context.save()
    }

    // MARK: - Builders

    @discardableResult
    private static func makeWorkspace(_ name: String, context: ModelContext) -> Workspace {
        let ws = Workspace(name: name)
        ws.projects  = []
        ws.labels    = []
        ws.savedViews = []
        context.insert(ws)
        return ws
    }

    @discardableResult
    private static func makeProject(_ name: String, workspace: Workspace, context: ModelContext) -> Project {
        let project = Project(name: name)
        project.workspace = workspace
        if workspace.projects == nil { workspace.projects = [] }
        workspace.projects?.append(project)
        project.issues = []
        context.insert(project)
        return project
    }

    @discardableResult
    private static func makeLabel(_ name: String, hex: String, workspace: Workspace, context: ModelContext) -> Label {
        let label = Label(name: name, colorHex: hex)
        label.workspace = workspace
        label.issues = []
        if workspace.labels == nil { workspace.labels = [] }
        workspace.labels?.append(label)
        context.insert(label)
        return label
    }

    @discardableResult
    private static func makeIssue(
        title: String,
        details: String = "",
        status: IssueStatus,
        priority: IssuePriority,
        project: Project,
        labels: [Label],
        context: ModelContext
    ) -> Issue {
        let issue = Issue(title: title)
        issue.details  = details
        issue.status   = status
        issue.priority = priority
        issue.project  = project
        issue.labels   = []

        // Wire many-to-many from both sides
        for label in labels {
            issue.labels?.append(label)
            if label.issues == nil { label.issues = [] }
            label.issues?.append(issue)
        }

        if project.issues == nil { project.issues = [] }
        project.issues?.append(issue)
        context.insert(issue)
        return issue
    }
}
