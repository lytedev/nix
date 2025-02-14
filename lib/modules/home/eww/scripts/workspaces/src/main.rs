mod workspace {
    pub struct Workspace {
        id: usize,
        icon: char,
        pub is_active: bool,
        pub is_occupied: bool,
        pub is_focused: bool,
    }

    impl Workspace {
        pub fn new(id: usize) -> Self {
            Self {
                id,
                icon: id.to_string().chars().next().unwrap_or('?'),
                is_active: false,
                is_occupied: false,
                is_focused: false,
            }
        }

        pub fn id(&self) -> usize {
            return self.id;
        }

        pub fn icon(&self) -> char {
            return self.icon;
        }

        pub fn clear_states(&mut self) {
            self.is_active = false;
            self.is_occupied = false;
            self.is_focused = false;
        }
    }
}

mod eww {}

mod hypr {
    pub mod hyprland {

        pub mod workspace {
            pub type Id = usize;
            pub type Name = String;
        }

        pub mod socket2 {
            use super::workspace;
            use std::{error::Error, fmt::Display, num::ParseIntError, str::FromStr};

            #[derive(Debug)]
            pub enum Event {
                Workspace(workspace::Id),
                Exit(),
                WorkspaceV2(String, String),
            }

            #[derive(Debug)]
            pub enum EventParseError {
                UnknownEventType(String),
                MissingParameters(String),
                InvalidParameters(String, String),
                ParseIntError(ParseIntError),
            }

            impl From<ParseIntError> for EventParseError {
                fn from(value: ParseIntError) -> Self {
                    Self::ParseIntError(value)
                }
            }

            impl Error for EventParseError {}

            impl Display for EventParseError {
                fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                    match self {
                        EventParseError::UnknownEventType(event_type) => {
                            write!(f, "unknown event type: {event_type}")
                        }

                        EventParseError::MissingParameters(event_type) => {
                            write!(f, "missing parameters for event type: {event_type}")
                        }

                        EventParseError::ParseIntError(err) => {
                            write!(f, "error parsing integer: {err}")
                        }
                        EventParseError::InvalidParameters(event_type, params) => {
                            write!(
                                f,
                                "invalid parameters for event type {event_type}: {params}"
                            )
                        }
                    }
                }
            }

            impl FromStr for Event {
                type Err = EventParseError;

                fn from_str(s: &str) -> Result<Self, Self::Err> {
                    let (event_type, rest): (&str, Option<&str>) = s
                        .find(">>")
                        .map(|n| {
                            let (a, b) = s.split_at(n);
                            (a, Option::Some(&b[2..]))
                        })
                        .unwrap_or((s, Option::None));
                    match (event_type, rest) {
                        ("workspace", None) => {
                            Err(EventParseError::MissingParameters(event_type.to_string()))
                        }
                        ("workspace", Some(workspace)) => Ok(Event::Workspace(workspace.parse()?)),
                        ("workspacev2", Some(args)) => {
                            let args: (String, String) = args
                                .split_once(',')
                                .map(|(a, b)| (a.to_string(), b.to_string()))
                                .ok_or(EventParseError::InvalidParameters(
                                    event_type.to_string(),
                                    args.to_string(),
                                ))?;
                            Ok(Event::WorkspaceV2(args.0, args.1))
                        }
                        ("exit", _) => Ok(Event::Exit()),
                        _ => Err(EventParseError::UnknownEventType(event_type.to_string())),
                    }
                }
            }
        }
    }
}

use hypr::hyprland::socket2::Event;
use std::{
    collections::HashMap,
    env,
    error::Error,
    io::{BufRead, BufReader},
    os::unix::net::UnixStream,
};
use workspace::Workspace;

fn main() -> Result<(), Box<dyn Error>> {
    let mut workspaces: HashMap<usize, Workspace> =
        (1..=9).map(|n| (n, Workspace::new(n))).collect();
    let path = format!(
        "{}/hypr/{}/.socket2.sock",
        env::var("XDG_RUNTIME_DIR")?,
        env::var("HYPRLAND_INSTANCE_SIGNATURE")?
    );

    eprintln!("opening {}", path);
    let stream = UnixStream::connect(&path)?;
    let event_lines = BufReader::new(stream).lines();
    for l in event_lines.into_iter() {
        match l?.parse::<Event>() {
            Ok(e) => match e {
                Event::Workspace(i) => match workspaces.get_mut(&i) {
                    Some(related_workspace) => {
                        eprintln!(
                            "setting workspace {} (id: {}) as active",
                            related_workspace.icon(),
                            related_workspace.id()
                        );
                        related_workspace.is_active = true
                    }
                    None => {
                        eprintln!("event for untracked workspace {}", i);
                    }
                },
                Event::Exit() => break,
                other => {
                    eprintln!("unhandled event: {:?}", other);
                }
            },
            Err(e) => eprintln!("error parsing event: {}", e),
        }
        render(&workspaces)?;
    }

    Ok(())
}

fn render(workspaces: &HashMap<usize, Workspace>) -> Result<(), Box<dyn Error>> {
    Ok(())
}
