use crate::actions::{Action, ParamSpec};
use std::collections::HashMap;

pub fn shell_quote(value: &str) -> String {
    if !value.is_empty()
        && value
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '@' | '_' | '-' | '.' | '/'))
    {
        return value.to_string();
    }

    format!("'{}'", value.replace('\'', "'\\''"))
}

pub fn render_template(template: &str, values: &HashMap<String, String>) -> String {
    let mut rendered = template.to_string();
    for (name, value) in values {
        rendered = rendered.replace(&format!("{{{name}}}"), &shell_quote(value));
    }
    rendered
}

pub fn render_action(action: &Action, values: &HashMap<String, String>) -> String {
    action
        .steps
        .iter()
        .map(|step| render_template(step.shortcut, values))
        .collect::<Vec<_>>()
        .join(" && ")
}

pub fn default_values(action: &Action) -> HashMap<String, String> {
    let mut values = HashMap::new();
    for param in action.params {
        match param {
            ParamSpec::Bookmark {
                name,
                default: Some(default),
                ..
            }
            | ParamSpec::Revision {
                name,
                default: Some(default),
                ..
            } => {
                values.insert((*name).to_string(), (*default).to_string());
            }
            _ => {}
        }
    }
    values
}

pub fn render_action_with_defaults(action: &Action) -> String {
    let values = default_values(action);
    render_action(action, &values)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::actions::actions;
    use std::collections::HashMap;

    #[test]
    fn shell_quote_leaves_safe_words_unquoted() {
        assert_eq!(shell_quote("main"), "main");
        assert_eq!(shell_quote("@"), "@");
        assert_eq!(shell_quote("trunk()"), "'trunk()'");
    }

    #[test]
    fn shell_quote_handles_spaces_and_single_quotes() {
        assert_eq!(shell_quote("hello world"), "'hello world'");
        assert_eq!(shell_quote("don't"), "'don'\\''t'");
    }

    #[test]
    fn render_template_replaces_named_parameters() {
        let mut values = HashMap::new();
        values.insert("bookmark".to_string(), "main".to_string());

        assert_eq!(
            render_template("jjgp --bookmark {bookmark}", &values),
            "jjgp --bookmark main"
        );
    }

    #[test]
    fn render_action_joins_steps_with_and_and() {
        let action = actions()
            .into_iter()
            .find(|a| a.id == "land-main")
            .expect("land-main action");
        let mut values = HashMap::new();
        values.insert("bookmark".to_string(), "main".to_string());

        assert_eq!(
            render_action(&action, &values),
            "jj sync && jj evolve && jj tug main && jjgp --bookmark main"
        );
    }
}
