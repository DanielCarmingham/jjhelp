#[derive(Clone, Debug, PartialEq, Eq)]
#[allow(dead_code)]
pub enum ParamSpec {
    Bookmark {
        name: &'static str,
        default: Option<&'static str>,
        prompt: bool,
    },
    Revision {
        name: &'static str,
        default: Option<&'static str>,
        prompt: bool,
    },
    File {
        name: &'static str,
    },
    Remote {
        name: &'static str,
    },
    Text {
        name: &'static str,
        prompt: &'static str,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Step {
    pub shortcut: &'static str,
    pub expanded: Option<&'static str>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Action {
    pub id: &'static str,
    pub title: &'static str,
    pub description: &'static str,
    pub tags: &'static [&'static str],
    pub params: &'static [ParamSpec],
    pub steps: &'static [Step],
}

impl Action {
    pub fn candidate_row(&self) -> String {
        let tags = self.tags.join(" ");
        let shortcuts = self
            .steps
            .iter()
            .map(|step| step.shortcut)
            .collect::<Vec<_>>()
            .join(" ");
        let expanded = self
            .steps
            .iter()
            .filter_map(|step| step.expanded)
            .collect::<Vec<_>>()
            .join(" ");
        let visible = format!(
            "{}  {}  {}",
            ansi("1", self.title),
            ansi("36", &shortcut_summary(self)),
            ansi("2", &tags)
        );

        format!(
            "{}\t{}\t{}\t{}\t{}\t{}",
            self.id, visible, tags, shortcuts, expanded, self.description
        )
    }

    pub fn preview(&self) -> String {
        let mut out = String::new();
        out.push_str(&ansi("1;36", self.title));
        out.push_str("\n\n");
        out.push_str(&ansi("1;34", "WHY"));
        out.push_str("\n  ");
        out.push_str(self.description);
        out.push_str("\n\n");
        out.push_str(&ansi("1;34", "STEPS"));
        out.push('\n');

        for (index, step) in self.steps.iter().enumerate() {
            out.push_str(&format!(
                "  {:>2}  {}\n",
                index + 1,
                ansi("1", step.shortcut)
            ));
            if let Some(expanded) = step.expanded {
                out.push_str(&format!("      {}\n", ansi("2", expanded)));
            }
            out.push('\n');
        }

        out.push_str(&ansi("1;34", "INSERTS"));
        out.push_str("\n  ");
        out.push_str(&ansi("1", &self.shortcut_command()));
        out
    }

    fn shortcut_command(&self) -> String {
        self.steps
            .iter()
            .map(|step| step.shortcut)
            .collect::<Vec<_>>()
            .join(" && ")
    }
}

fn shortcut_summary(action: &Action) -> String {
    action
        .steps
        .iter()
        .map(|step| step.shortcut)
        .collect::<Vec<_>>()
        .join(" · ")
}

fn ansi(code: &str, text: &str) -> String {
    format!("\x1b[{code}m{text}\x1b[0m")
}

const LAND_MAIN_PARAMS: &[ParamSpec] = &[ParamSpec::Bookmark {
    name: "bookmark",
    default: Some("main"),
    prompt: false,
}];

const BOOKMARK_PROMPT_PARAMS: &[ParamSpec] = &[ParamSpec::Bookmark {
    name: "bookmark",
    default: Some("main"),
    prompt: true,
}];

const MESSAGE_PARAMS: &[ParamSpec] = &[ParamSpec::Text {
    name: "message",
    prompt: "message>",
}];

const LAND_MAIN_STEPS: &[Step] = &[
    Step {
        shortcut: "jj sync",
        expanded: Some("jj git fetch --all-remotes"),
    },
    Step {
        shortcut: "jj evolve",
        expanded: Some("jj rebase --skip-emptied -o trunk()"),
    },
    Step {
        shortcut: "jj tug {bookmark}",
        expanded: Some("jj bookmark advance {bookmark}"),
    },
    Step {
        shortcut: "jjgp --bookmark {bookmark}",
        expanded: Some("jj git push --bookmark {bookmark}"),
    },
];

const CATCH_UP_STEPS: &[Step] = &[
    Step {
        shortcut: "jj sync",
        expanded: Some("jj git fetch --all-remotes"),
    },
    Step {
        shortcut: "jj evolve",
        expanded: Some("jj rebase --skip-emptied -o trunk()"),
    },
];

const DESCRIBE_STEPS: &[Step] = &[Step {
    shortcut: "jjdmsg {message}",
    expanded: Some("jj desc --message {message}"),
}];

const SPLIT_STEPS: &[Step] = &[Step {
    shortcut: "jjsp",
    expanded: Some("jj split"),
}];

const UNDO_STEPS: &[Step] = &[
    Step {
        shortcut: "jj op log",
        expanded: None,
    },
    Step {
        shortcut: "jj undo",
        expanded: None,
    },
];

const INSPECT_STEPS: &[Step] = &[
    Step {
        shortcut: "jjst",
        expanded: Some("jj status"),
    },
    Step {
        shortcut: "jj mdiff",
        expanded: Some("jj diff --from trunk()"),
    },
    Step {
        shortcut: "jj ls",
        expanded: Some("jj diff --name-only"),
    },
];

const MOVE_BOOKMARK_STEPS: &[Step] = &[Step {
    shortcut: "jj tug {bookmark}",
    expanded: Some("jj bookmark advance {bookmark}"),
}];

const PUSH_BOOKMARK_STEPS: &[Step] = &[Step {
    shortcut: "jjgp --bookmark {bookmark}",
    expanded: Some("jj git push --bookmark {bookmark}"),
}];

pub static ACTIONS: &[Action] = &[
    Action {
        id: "land-main",
        title: "land current work on main",
        description: "Move main to the current change and push main to origin.",
        tags: &["push", "publish", "done", "main", "bookmark"],
        params: LAND_MAIN_PARAMS,
        steps: LAND_MAIN_STEPS,
    },
    Action {
        id: "catch-up",
        title: "catch up with remote main",
        description: "Fetch remote changes and rebase your work onto the new trunk.",
        tags: &["fetch", "pull", "sync", "rebase", "update"],
        params: &[],
        steps: CATCH_UP_STEPS,
    },
    Action {
        id: "describe-change",
        title: "describe current change",
        description: "Set the description for the current jj change.",
        tags: &["message", "commit", "describe", "name"],
        params: MESSAGE_PARAMS,
        steps: DESCRIBE_STEPS,
    },
    Action {
        id: "split-change",
        title: "split current change",
        description: "Split the current change into smaller changes.",
        tags: &["split", "stage", "partial", "hunk"],
        params: &[],
        steps: SPLIT_STEPS,
    },
    Action {
        id: "undo-last-operation",
        title: "undo last jj operation",
        description: "Inspect recent operations and undo the last jj operation.",
        tags: &["undo", "recover", "rollback", "mistake"],
        params: &[],
        steps: UNDO_STEPS,
    },
    Action {
        id: "inspect-change",
        title: "inspect current change",
        description: "Show status, diff from trunk, and files touched by the current change.",
        tags: &["status", "diff", "files", "inspect"],
        params: &[],
        steps: INSPECT_STEPS,
    },
    Action {
        id: "move-bookmark",
        title: "move bookmark to current change",
        description: "Advance a selected bookmark to the current change.",
        tags: &["bookmark", "advance", "move", "tug"],
        params: BOOKMARK_PROMPT_PARAMS,
        steps: MOVE_BOOKMARK_STEPS,
    },
    Action {
        id: "push-bookmark",
        title: "push bookmark",
        description: "Push a selected bookmark to the configured git remote.",
        tags: &["push", "bookmark", "remote", "publish"],
        params: BOOKMARK_PROMPT_PARAMS,
        steps: PUSH_BOOKMARK_STEPS,
    },
];

pub fn actions() -> &'static [Action] {
    ACTIONS
}

pub fn find_action(id: &str) -> Option<&'static Action> {
    actions().iter().find(|action| action.id == id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn action_registry_contains_first_version_actions() {
        let ids: Vec<&str> = actions().iter().map(|a| a.id).collect();
        assert_eq!(
            ids,
            vec![
                "land-main",
                "catch-up",
                "describe-change",
                "split-change",
                "undo-last-operation",
                "inspect-change",
                "move-bookmark",
                "push-bookmark",
            ]
        );
    }

    #[test]
    fn candidate_row_contains_id_title_tags_shortcuts_expansions_and_description() {
        let action = actions()
            .into_iter()
            .find(|a| a.id == "land-main")
            .expect("land-main action");

        let row = action.candidate_row();

        assert!(row.contains("land-main"));
        assert!(row.contains("land current work on main"));
        assert!(row.contains("push publish done main bookmark"));
        assert!(row.contains("jj tug {bookmark}"));
        assert!(row.contains("jj bookmark advance {bookmark}"));
        assert!(row.contains("Move main to the current change"));
    }

    #[test]
    fn candidate_row_styles_visible_content_but_keeps_hidden_search_fields() {
        let action = actions()
            .into_iter()
            .find(|a| a.id == "land-main")
            .expect("land-main action");

        let row = action.candidate_row();
        let fields = row.split('\t').collect::<Vec<_>>();

        assert_eq!(fields[0], "land-main");
        assert!(fields[1].contains("\x1b[1m"));
        assert!(fields[1].contains("land current work on main"));
        assert!(fields[1].contains("jj sync"));
        assert!(fields[1].contains("push publish done"));
        assert_eq!(fields[2], "push publish done main bookmark");
        assert!(fields[3].contains("jj tug {bookmark}"));
        assert!(fields[4].contains("jj bookmark advance {bookmark}"));
        assert!(fields[5].contains("Move main to the current change"));
    }

    #[test]
    fn preview_teaches_shortcuts_and_expanded_commands() {
        let action = actions()
            .into_iter()
            .find(|a| a.id == "land-main")
            .expect("land-main action");

        let preview = action.preview();

        assert!(preview.contains("WHY"));
        assert!(preview.contains("jj sync"));
        assert!(preview.contains("jj git fetch --all-remotes"));
        assert!(preview.contains("jj tug {bookmark}"));
        assert!(preview.contains("jj bookmark advance {bookmark}"));
        assert!(preview.contains("INSERTS"));
    }

    #[test]
    fn preview_uses_ansi_sections_and_command_hierarchy() {
        let action = actions()
            .into_iter()
            .find(|a| a.id == "land-main")
            .expect("land-main action");

        let preview = action.preview();

        assert!(preview.contains("\x1b[1;36mland current work on main\x1b[0m"));
        assert!(preview.contains("\x1b[1;34mWHY\x1b[0m"));
        assert!(preview.contains("\x1b[1;34mSTEPS\x1b[0m"));
        assert!(preview.contains("\x1b[1;34mINSERTS\x1b[0m"));
        assert!(preview.contains("\x1b[1mjj sync\x1b[0m"));
        assert!(preview.contains("\x1b[2mjj git fetch --all-remotes\x1b[0m"));
    }
}
