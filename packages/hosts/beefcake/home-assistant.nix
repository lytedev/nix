# Home Assistant — the household's voice automation control plane, moved off
# bigtower to beefcake so it's backed up (restic), TLS-routed
# (home-assistant.h.lyte.dev via Caddy), and on the always-on server. Runs
# NATIVELY (services.home-assistant), not in a container. The /var/lib/hass
# data dir (HA 2026.6.4) carries over from bigtower; because HA storage
# migrations are forward-only, we pin the package to
# pkgs.unstable-packages.home-assistant (2026.6.4) since beefcake's stable
# nixpkgs only ships 2026.5.4.
#
# Wyoming (faster-whisper / piper / openwakeword) also moves here, native, so
# the whole voice pipeline lives on one always-on host.
#
# The rest_command / intent_script / automation blocks below are ported
# VERBATIM from the bigtower lytebot module
# (lytebot-alexa/modules/home-assistant.nix); the orchestrator/ollama/zeroclaw
# branches that don't exist on beefcake are dropped.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  hassSecretsPath = config.sops.templates."hass-secrets.yaml".path;
in
{
  services.home-assistant = {
    enable = true;

    # /var/lib/hass is HA 2026.6.4 and storage migrations are forward-only;
    # beefcake's 26.05 nixpkgs ships only 2026.5.4, so pin to unstable.
    package = pkgs.unstable-packages.home-assistant;

    extraComponents = [
      "default_config" # includes rest_command, used for the Hearth intent API
      "met"
      "esphome"
      "wyoming"
      "assist_pipeline" # Voice pipeline management
      "music_assistant"
    ];

    config = {
      homeassistant = {
        name = "Home";
        unit_system = "us_customary";
        time_zone = "America/Chicago";
      };
      http = {
        # clickhouse owns 127.0.0.1:8123 on beefcake, so HA listens on 8124.
        server_port = 8124;
        # Behind Caddy (home-assistant.h.lyte.dev → reverse_proxy :8124).
        use_x_forwarded_for = true;
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };

      # Custom YAML-based dashboards
      lovelace = {
        mode = "storage";
        dashboards = {
          lovelace-wall = {
            mode = "yaml";
            filename = "dashboards/wall.yaml";
            title = "Wall Display";
            icon = "mdi:monitor";
            show_in_sidebar = true;
            require_admin = false;
          };
        };
      };

      # Hearth dashboard intent API (token-authed). The Authorization value
      # is `Bearer <token>` stored whole in HA's secrets.yaml (provisioned by
      # sops below) so `!secret` can supply it — YAML can't concatenate a
      # literal "Bearer " with a `!secret` tag.
      rest_command = {
        hearth_timer = {
          url = "https://hearth.h.lyte.dev/api/intent/timer/create";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"label": "{{ label }}", "minutes": {{ minutes | int }} }'';
        };
        hearth_task = {
          url = "https://hearth.h.lyte.dev/api/intent/task/create";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"title": "{{ title }}"}'';
        };
        hearth_grocery = {
          url = "https://hearth.h.lyte.dev/api/intent/grocery/add";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"name": "{{ item }}"}'';
        };
        # Hearth parses {{ when }} (natural language) server-side. tojson keeps
        # apostrophes ("dad's appointment") and quotes from breaking the JSON.
        hearth_event = {
          url = "https://hearth.h.lyte.dev/api/intent/event/create";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"name": {{ name | tojson }}, "when": {{ when | tojson }} }'';
        };
        # Read back upcoming events. Hearth formats the spoken summary; HA just
        # speaks response.content.summary. {{ range }} = today|tomorrow|week.
        hearth_events = {
          url = "https://hearth.h.lyte.dev/api/intent/event/list?range={{ range }}";
          method = "GET";
          headers.Authorization = "!secret hearth_auth";
        };
        # Meal plan: set/replace a day's dinner; Hearth parses {{ when }}.
        hearth_meal_set = {
          url = "https://hearth.h.lyte.dev/api/intent/meal/set";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"meal": {{ meal | tojson }}, "when": {{ when | tojson }} }'';
        };
        # Ask what's planned; Hearth formats response.content.summary to speak.
        hearth_meal_get = {
          url = "https://hearth.h.lyte.dev/api/intent/meal/get?when={{ when }}";
          method = "GET";
          headers.Authorization = "!secret hearth_auth";
        };
        # Push a recipe's ingredients to the grocery list.
        hearth_grocery_from_recipe = {
          url = "https://hearth.h.lyte.dev/api/intent/grocery/from_recipe";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"recipe": {{ recipe | tojson }} }'';
        };
        # Pantry inventory.
        hearth_pantry_add = {
          url = "https://hearth.h.lyte.dev/api/intent/pantry/add";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"item": {{ item | tojson }} }'';
        };
        hearth_pantry_remove = {
          url = "https://hearth.h.lyte.dev/api/intent/pantry/remove";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"item": {{ item | tojson }} }'';
        };
        hearth_pantry_has = {
          url = "https://hearth.h.lyte.dev/api/intent/pantry/has?item={{ item | urlencode }}";
          method = "GET";
          headers.Authorization = "!secret hearth_auth";
        };
        hearth_pantry_list = {
          url = "https://hearth.h.lyte.dev/api/intent/pantry/list";
          method = "GET";
          headers.Authorization = "!secret hearth_auth";
        };
        # Mark a meal cooked → subtract its recipe ingredients from the pantry.
        hearth_meal_cooked = {
          url = "https://hearth.h.lyte.dev/api/intent/meal/cooked";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"when": {{ when | tojson }} }'';
        };
        # Log a command Hearth couldn't act on (the catch-all intent) so we can
        # see what the household expects to be able to say.
        hearth_unrecognized = {
          url = "https://hearth.h.lyte.dev/api/intent/unrecognized";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"text": {{ text | tojson }} }'';
        };
        # Dismiss all fired timers (used by "stop"). With the timer gone,
        # Hearth's scheduler stops re-announcing on the satellites.
        hearth_dismiss_fired = {
          url = "https://hearth.h.lyte.dev/api/intent/timer/dismiss_fired";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = "{}";
        };
        # Audiobookshelf "continue listening" — newest-first list of
        # in-progress items. Used by HearthResumeAudiobook to resume the most
        # recent audiobook cold (when nothing is loaded to media_play).
        abs_items_in_progress = {
          url = "https://audio.lyte.dev/api/me/items-in-progress";
          method = "GET";
          headers.Authorization = "!secret abs_auth";
        };
        # Push current MA playback to Hearth's Now Playing widget. Hearth (on
        # beefcake) can't reach MA, so HA — which can — is the source of truth.
        hearth_now_playing = {
          url = "https://hearth.h.lyte.dev/api/intent/now_playing";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret hearth_auth";
          payload = ''{"player": {{ player | tojson }}, "state": {{ state | tojson }}, "title": {{ title | tojson }}, "subtitle": {{ subtitle | tojson }}, "media_type": {{ media_type | tojson }}, "image": {{ image | tojson }} }'';
        };
        # Steamdeck tv-player control service (video on the TV via mpv/yt-dlp).
        # IP is the deck's current DHCP lease (192.168.0.69); update if it moves.
        tv_play = {
          url = "http://192.168.0.69:8730/play";
          method = "POST";
          content_type = "application/json";
          headers.Authorization = "!secret tv_auth";
          payload = ''{"source": "youtube", "query": {{ query | tojson }} }'';
        };
        tv_stop = {
          url = "http://192.168.0.69:8730/stop";
          method = "POST";
          headers.Authorization = "!secret tv_auth";
        };
      };

      # When the kitchen MA speaker changes (play/pause/stop/track), push the
      # current track to Hearth's Now Playing widget. media_type is derived
      # from the content id (podcasts/audiobooks come through Audiobookshelf).
      automation = [
        {
          alias = "Push Music Assistant now-playing to Hearth";
          mode = "queued";
          trigger = [
            {
              platform = "state";
              entity_id = [ "media_player.master_bedroom_speaker" ];
            }
          ];
          # Double-quoted nix strings here (NOT '' strings): the Jinja empty
          # literals '' would otherwise close a nix '' string early.
          action = [
            {
              service = "rest_command.hearth_now_playing";
              data = {
                player = "{{ state_attr(trigger.entity_id, 'friendly_name') | default('', true) }}";
                state = "{{ states(trigger.entity_id) }}";
                title = "{{ state_attr(trigger.entity_id, 'media_title') | default('', true) }}";
                subtitle = "{{ state_attr(trigger.entity_id, 'media_artist') or state_attr(trigger.entity_id, 'media_album_name') or state_attr(trigger.entity_id, 'media_series_title') or '' }}";
                media_type = "{% set cid = state_attr(trigger.entity_id, 'media_content_id') | default('', true) | string %}{% if 'podcast' in cid %}podcast{% elif 'audiobook' in cid %}audiobook{% else %}music{% endif %}";
                # entity_picture is a relative /api/media_player_proxy/...?token=
                # path; Hearth prepends the HA base + re-serves it over https.
                image = "{{ state_attr(trigger.entity_id, 'entity_picture') | default('', true) }}";
              };
            }
          ];
        }
      ];

      intent_script = {
        # Parse the {timer_spec} wildcard into minutes + an optional label,
        # robust to STT quirks ("10-minute pasta", "5 minutes", "1 hour").
        HearthStartTimer = {
          speech.text = "{% set nums = timer_spec | regex_findall('[0-9]+') %}{% if nums %}Starting a {{ nums | first }} {% if 'hour' in timer_spec or 'hr' in timer_spec %}hour{% else %}minute{% endif %} timer.{% else %}Sorry, I did not catch the duration.{% endif %}";
          action = [
            {
              variables = {
                mins = "{% set nums = timer_spec | regex_findall('[0-9]+') %}{% set base = (nums | first | int) if nums else 0 %}{{ base * (60 if ('hour' in timer_spec or 'hr' in timer_spec) else 1) }}";
                label = "{% set l = timer_spec | regex_replace('[0-9]+[ -]*(minutes?|mins?|hours?|hrs?)', ' ') | regex_replace('[ ]+', ' ') | trim %}{{ l if l else 'timer' }}";
              };
            }
            {
              service = "rest_command.hearth_timer";
              data = {
                minutes = "{{ mins }}";
                label = "{{ label }}";
              };
            }
          ];
        };
        HearthAddTask = {
          speech.text = "Added {{ title }} to the tasks.";
          action = [
            {
              service = "rest_command.hearth_task";
              data.title = "{{ title }}";
            }
          ];
        };
        HearthAddGrocery = {
          speech.text = "Added {{ item }} to the grocery list.";
          action = [
            {
              service = "rest_command.hearth_grocery";
              data.item = "{{ item }}";
            }
          ];
        };
        # Read back the *resolved* date Hearth parsed (response.content.spoken),
        # so a mis-heard/mis-parsed time is obvious and can be corrected.
        HearthAddEvent = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.spoken is defined %}Added {{ event_name }} for {{ c.spoken }}.{% else %}Sorry, I couldn't add that event.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_event";
              data = {
                name = "{{ event_name }}";
                when = "{{ event_when }}";
              };
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        # Plan a dinner; read back the resolved day Hearth parsed.
        HearthSetMeal = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.spoken is defined %}Planned {{ c.spoken }}.{% else %}Sorry, I couldn't plan that meal.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_meal_set";
              data = {
                meal = "{{ meal_name }}";
                when = "{{ meal_when | default('today', true) }}";
              };
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        # "What's for dinner [tonight|tomorrow|friday]?"
        HearthWhatsForDinner = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.summary is defined %}{{ c.summary }}{% else %}Sorry, I couldn't reach the meal plan.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_meal_get";
              data.when = "{{ meal_when | default('today', true) }}";
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        # "Add the ingredients for {recipe} to the grocery list."
        HearthGroceriesFromRecipe = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.summary is defined %}{{ c.summary }}{% else %}Sorry, I couldn't reach the recipes.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_grocery_from_recipe";
              data.recipe = "{{ recipe_name }}";
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        # Pantry: add / remove / have-we-got / list, plus mark-cooked. All
        # speak Hearth's response.content.summary.
        HearthPantryAdd = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.summary is defined %}{{ c.summary }}{% else %}Sorry, I couldn't update the pantry.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_pantry_add";
              data.item = "{{ pantry_item }}";
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        HearthPantryRemove = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.summary is defined %}{{ c.summary }}{% else %}Sorry, I couldn't update the pantry.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_pantry_remove";
              data.item = "{{ pantry_item }}";
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        HearthPantryHas = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.summary is defined %}{{ c.summary }}{% else %}Sorry, I couldn't check the pantry.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_pantry_has";
              data.item = "{{ pantry_item }}";
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        HearthPantryList = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.summary is defined %}{{ c.summary }}{% else %}Sorry, I couldn't check the pantry.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_pantry_list";
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        HearthMealCooked = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.summary is defined %}{{ c.summary }}{% else %}Okay.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_meal_cooked";
              data.when = "{{ meal_when | default('today', true) }}";
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        # Play music via Music Assistant. {{ music_query }} is searched by MA;
        # {{ music_player }} (a media_player entity from the room list) picks
        # the output, defaulting to the master bedroom speaker.
        HearthPlayMusic = {
          speech.text = "Playing {{ music_query }}.";
          action = [
            {
              service = "music_assistant.play_media";
              target.entity_id = "{{ music_player | default('media_player.master_bedroom_speaker', true) }}";
              data.media_id = "{{ music_query }}";
            }
          ];
        };
        # "play X everywhere" — play the same media to every room. Cast and
        # squeezelite players can't sample-sync-group across protocols, so
        # we just target both speakers; in separate rooms the slight offset
        # is inaudible. Extend the entity list as more rooms appear.
        HearthPlayEverywhere = {
          speech.text = "Playing {{ music_query }} everywhere.";
          action = [
            {
              service = "music_assistant.play_media";
              target.entity_id = [
                "media_player.master_bedroom_speaker"
                "media_player.living_room"
              ];
              data.media_id = "{{ music_query }}";
            }
          ];
        };
        # Video on the TV (steamdeck mpv via the tv-player service). The
        # query is YouTube-searched by yt-dlp. "on the TV" = the screen;
        # "in the living room" = the speaker (kept distinct).
        HearthPlayTvVideo = {
          speech.text = "Playing {{ video_query }} on the TV.";
          action = [
            {
              service = "rest_command.tv_play";
              data.query = "{{ video_query }}";
            }
          ];
        };
        HearthStopTv = {
          speech.text = "Okay.";
          action = [ { service = "rest_command.tv_stop"; } ];
        };
        # Play an audiobook from the Audiobookshelf library (via MA).
        # media_type=audiobook makes MA resume from the listener's saved
        # position (ABS tracks per-user progress), so "play the audiobook X"
        # picks up where they left off rather than restarting.
        HearthPlayAudiobook = {
          speech.text = "Playing {{ audiobook_name }}.";
          action = [
            {
              service = "music_assistant.play_media";
              target.entity_id = "{{ music_player | default('media_player.master_bedroom_speaker', true) }}";
              data.media_id = "{{ audiobook_name }}";
              data.media_type = "audiobook";
            }
          ];
        };
        # "resume my audiobook" — if a Music Assistant player is paused,
        # just resume it. Otherwise (cold start) ask Audiobookshelf for the
        # most-recent in-progress audiobook and play it by title, which
        # resumes from the saved position.
        HearthResumeAudiobook = {
          speech.text = "Resuming your audiobook.";
          action = [
            {
              choose = [
                {
                  # Something is paused — resume it in place.
                  conditions = [
                    {
                      condition = "template";
                      value_template = "{{ integration_entities('music_assistant') | select('is_state','paused') | list | length > 0 }}";
                    }
                  ];
                  sequence = [
                    {
                      service = "media_player.media_play";
                      target.entity_id = "{{ integration_entities('music_assistant') | select('is_state','paused') | list }}";
                    }
                  ];
                }
              ];
              # Cold: look up the newest in-progress book and play it.
              default = [
                {
                  service = "rest_command.abs_items_in_progress";
                  response_variable = "abs";
                }
                {
                  "if" = [
                    {
                      condition = "template";
                      value_template = "{{ abs.status == 200 and (abs.content.libraryItems | default([]) | selectattr('mediaType','eq','book') | list | length) > 0 }}";
                    }
                  ];
                  "then" = [
                    {
                      service = "music_assistant.play_media";
                      target.entity_id = "{{ music_player | default('media_player.master_bedroom_speaker', true) }}";
                      data = {
                        media_id = "{{ (abs.content.libraryItems | selectattr('mediaType','eq','book') | list | first).media.metadata.title }}";
                        media_type = "audiobook";
                      };
                    }
                  ];
                }
              ];
            }
          ];
        };
        # Play a podcast from the Audiobookshelf library (via MA).
        # media_type=podcast → MA plays/resumes the right episode from the
        # listener's saved progress.
        HearthPlayPodcast = {
          speech.text = "Playing {{ podcast_name }}.";
          action = [
            {
              service = "music_assistant.play_media";
              target.entity_id = "{{ music_player | default('media_player.master_bedroom_speaker', true) }}";
              data = {
                media_id = "{{ podcast_name }}";
                media_type = "podcast";
              };
            }
          ];
        };
        # "resume my podcast" — play the most-recent in-progress podcast by
        # title (media_type=podcast resumes the right episode + position).
        # play_media on an already-paused podcast just resumes it in place,
        # so a single cold-path branch covers both cases.
        HearthResumePodcast = {
          speech.text = "Resuming your podcast.";
          action = [
            {
              service = "rest_command.abs_items_in_progress";
              response_variable = "abs";
            }
            {
              "if" = [
                {
                  condition = "template";
                  value_template = "{{ abs.status == 200 and (abs.content.libraryItems | default([]) | selectattr('mediaType','eq','podcast') | list | length) > 0 }}";
                }
              ];
              "then" = [
                {
                  service = "music_assistant.play_media";
                  target.entity_id = "{{ music_player | default('media_player.master_bedroom_speaker', true) }}";
                  data = {
                    media_id = "{{ (abs.content.libraryItems | selectattr('mediaType','eq','podcast') | list | first).media.metadata.title }}";
                    media_type = "podcast";
                  };
                }
              ];
            }
          ];
        };
        # "move it to the living room" — transfer the active queue to another
        # room and keep playing. Destination is the {music_player} room; the
        # source is whichever MA player is currently active.
        # Re-play the source's exact current item (its media_content_id) on
        # the destination room, then stop the source. Content-agnostic and
        # robust: ABS audiobooks/podcasts resume from saved progress, music
        # replays the same track — and it sidesteps MA's transfer_queue
        # limitation with transient single-item queues. Double-quoted nix
        # strings here so the Jinja '' empty literals don't close them.
        HearthMoveMusic = {
          speech.text = "Moving it to the {{ state_attr(music_player, 'friendly_name') | default('other room', true) }}.";
          action = [
            {
              variables.src = "{{ (integration_entities('music_assistant') | select('match','^media_player\\.') | reject('is_state','idle') | reject('is_state','off') | reject('is_state','unavailable') | reject('is_state','standby') | list | first) | default('', true) }}";
            }
            {
              variables.cid = "{{ state_attr(src, 'media_content_id') | default('', true) }}";
            }
            {
              choose = [
                {
                  # Only if something's actually playing and it's a different room.
                  conditions = [
                    {
                      condition = "template";
                      value_template = "{{ src | length > 0 and cid | length > 0 and src != music_player }}";
                    }
                  ];
                  sequence = [
                    {
                      service = "music_assistant.play_media";
                      target.entity_id = "{{ music_player }}";
                      data.media_id = "{{ cid }}";
                    }
                    {
                      service = "media_player.media_stop";
                      target.entity_id = "{{ src }}";
                    }
                  ];
                }
              ];
            }
          ];
        };
        # Media controls — target whichever Music Assistant player is active
        # (not idle/off/unavailable), so "pause" etc. act on what's playing.
        HearthMusicPause = {
          speech.text = "Paused.";
          action = [
            {
              service = "media_player.media_pause";
              target.entity_id = "{{ integration_entities('music_assistant') | reject('is_state','idle') | reject('is_state','off') | reject('is_state','unavailable') | reject('is_state','standby') | list }}";
            }
          ];
        };
        HearthMusicResume = {
          speech.text = "Okay.";
          action = [
            {
              service = "media_player.media_play";
              target.entity_id = "{{ integration_entities('music_assistant') | select('is_state','paused') | list }}";
            }
          ];
        };
        HearthMusicNext = {
          speech.text = "";
          action = [
            {
              service = "media_player.media_next_track";
              target.entity_id = "{{ integration_entities('music_assistant') | reject('is_state','idle') | reject('is_state','off') | reject('is_state','unavailable') | reject('is_state','standby') | list }}";
            }
          ];
        };
        HearthMusicPrevious = {
          speech.text = "";
          action = [
            {
              service = "media_player.media_previous_track";
              target.entity_id = "{{ integration_entities('music_assistant') | reject('is_state','idle') | reject('is_state','off') | reject('is_state','unavailable') | reject('is_state','standby') | list }}";
            }
          ];
        };
        HearthMusicStop = {
          speech.text = "Stopped.";
          action = [
            {
              service = "media_player.media_stop";
              target.entity_id = "{{ integration_entities('music_assistant') | reject('is_state','idle') | reject('is_state','off') | reject('is_state','unavailable') | reject('is_state','standby') | list }}";
            }
          ];
        };
        HearthMusicVolumeUp = {
          speech.text = "";
          action = [
            {
              service = "media_player.volume_up";
              target.entity_id = "{{ integration_entities('music_assistant') | reject('is_state','idle') | reject('is_state','off') | reject('is_state','unavailable') | reject('is_state','standby') | list }}";
            }
          ];
        };
        HearthMusicVolumeDown = {
          speech.text = "";
          action = [
            {
              service = "media_player.volume_down";
              target.entity_id = "{{ integration_entities('music_assistant') | reject('is_state','idle') | reject('is_state','off') | reject('is_state','unavailable') | reject('is_state','standby') | list }}";
            }
          ];
        };
        HearthMusicVolumeSet = {
          speech.text = "Okay.";
          action = [
            {
              service = "media_player.volume_set";
              target.entity_id = "{{ integration_entities('music_assistant') | reject('is_state','idle') | reject('is_state','off') | reject('is_state','unavailable') | reject('is_state','standby') | list }}";
              data.volume_level = "{% set n = volume_pct | regex_findall('[0-9]+') %}{{ (n[0]|int / 100) if n else 0.3 }}";
            }
          ];
        };
        # Catch-all: any utterance that matched no other intent. A bare
        # {utterance} wildcard scores lowest in hassil, so real intents still
        # win; this only fires for genuinely unhandled commands, which we log
        # to learn what to support next.
        HearthUnknown = {
          speech.text = "Sorry, I can't do that yet.";
          action = [
            {
              service = "rest_command.hearth_unrecognized";
              data.text = "{{ utterance }}";
            }
          ];
        };
        # Speak Hearth's pre-formatted summary of upcoming events.
        HearthListEvents = {
          speech.text = "{% set c = action_response.content if action_response is defined and action_response is mapping else none %}{% if c is mapping and c.summary is defined %}{{ c.summary }}{% else %}Sorry, I couldn't reach the calendar.{% endif %}";
          action = [
            {
              service = "rest_command.hearth_events";
              data.range = "{{ cal_range | default('week', true) }}";
              response_variable = "result";
            }
            {
              stop = "";
              response_variable = "result";
            }
          ];
        };
        # "stop" / "okay nabu stop" while a timer is ringing: dismiss the
        # fired timer(s) in Hearth, which stops its scheduler from
        # re-announcing on the satellites.
        HearthStopAlarm = {
          speech.text = "Okay.";
          action = [
            { service = "rest_command.hearth_dismiss_fired"; }
          ];
        };
      };
    };

    configWritable = true;
  };

  # Remove dangling configuration.yaml before HA pre-start copies the new one
  # in (rollbacks leave a stale symlink). secrets.yaml is a tmpfiles symlink
  # to the sops-rendered file (below) — don't rm it here or HA boots into
  # recovery mode with "Secret hearth_auth not defined".
  systemd.services.home-assistant.preStart = lib.mkBefore ''
    rm -f /var/lib/hass/configuration.yaml
  '';

  # Custom sentences are read by HA at startup, and a deploy that changes only
  # the sentence file doesn't otherwise touch the unit — so HA would keep stale
  # grammar until a manual conversation.reload. Tie a restart to the file's
  # content so sentence edits reliably take effect on deploy.
  systemd.services.home-assistant.restartTriggers = [
    ./home-assistant/custom_sentences/en/hearth.yaml
  ];

  # Wyoming voice pipeline DEFERRED to bigtower (kept running there).
  # faster-whisper/piper/openwakeword pull ML deps (lightning/PyTorch) from this
  # unstable rev that Hydra has NOT cached (cache.nixos.org returns 404), so
  # building them here would mean compiling PyTorch from source — impractical.
  # bigtower already runs these natively, so HA's `wyoming` integration points at
  # bigtower over the tailnet (config_entries host 100.64.0.10:10300/10200/10400).
  # Re-enable native Wyoming here once these paths land in the binary cache:
  #   services.wyoming.faster-whisper.servers.hearth = { enable=true; model="small.en"; language="en"; uri="tcp://0.0.0.0:10300"; };
  #   services.wyoming.piper.servers.hearth = { enable=true; voice="en_US-lessac-medium"; uri="tcp://0.0.0.0:10200"; };
  #   services.wyoming.openwakeword = { enable=true; uri="tcp://0.0.0.0:10400"; threshold=0.3; extraArgs=["--preload-model" "alexa"]; };

  # Hearth intent-API bearer token, stored whole ("Bearer <token>") and
  # rendered into HA's secrets.yaml so `!secret hearth_auth` resolves.
  # NOTE: these keys must be populated in secrets/beefcake/secrets.yml before
  # cutover (the lead handles the encrypted values).
  sops.secrets."home-assistant/hearth-auth-header" = { };
  # Audiobookshelf bearer token (stored whole, "Bearer <token>"), used by the
  # abs_items_in_progress rest_command for cold "resume my audiobook".
  sops.secrets."home-assistant/abs-auth-header" = { };
  # Bearer token for the steamdeck's tv-player control service ("play X on
  # the TV" video). Stored whole ("Bearer <token>").
  sops.secrets."home-assistant/tv-control-auth" = { };
  sops.templates."hass-secrets.yaml" = {
    owner = "hass";
    group = "hass";
    mode = "0400";
    content = ''
      hearth_auth: ${config.sops.placeholder."home-assistant/hearth-auth-header"}
      abs_auth: ${config.sops.placeholder."home-assistant/abs-auth-header"}
      tv_auth: ${config.sops.placeholder."home-assistant/tv-control-auth"}
    '';
  };

  # Deploy custom sentences, dashboards, and HA secrets.yaml
  systemd.tmpfiles.rules = [
    # Declare the intermediate dir as hass-owned too — otherwise tmpfiles
    # auto-creates /var/lib/hass/custom_sentences as root and then refuses the
    # hass->root "unsafe path transition", silently skipping the file copies.
    "d /var/lib/hass/custom_sentences 0755 hass hass -"
    "d /var/lib/hass/custom_sentences/en 0755 hass hass -"
    # Symlink (not C+ copy) so edits to hearth.yaml actually propagate on
    # redeploy — C+ refuses to overwrite an existing file.
    "L+ /var/lib/hass/custom_sentences/en/hearth.yaml - - - - ${./home-assistant/custom_sentences/en/hearth.yaml}"
    "d /var/lib/hass/dashboards 0755 hass hass -"
    "C+ /var/lib/hass/dashboards/wall.yaml 0644 hass hass - ${./home-assistant/dashboards/wall.yaml}"
    "L+ /var/lib/hass/secrets.yaml - - - - ${hassSecretsPath}"
  ];

  # Public TLS via Caddy (home-assistant.h.lyte.dev → :8124). The DNS record
  # is already present in beefcake.nix's dns-updater records.
  services.caddy.virtualHosts."home-assistant.h.lyte.dev".extraConfig = ''
    reverse_proxy :8124
  '';

  # Back up the HA data dir (config, storage DB, tokens, history).
  services.restic.commonPaths = [ "/var/lib/hass" ];
}
