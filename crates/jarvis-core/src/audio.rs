mod kira;
mod rodio;

use once_cell::sync::OnceCell;
use std::path::PathBuf;

use crate::config::structs::AudioType;
use crate::{config, DB, SOUND_DIR};

static AUDIO_TYPE: OnceCell<AudioType> = OnceCell::new();

pub fn init() -> Result<(), ()> {
    if AUDIO_TYPE.get().is_some() {
        return Ok(());
    } // already initialized

    // set default audio type
    // @TODO. Make it configurable?
    AUDIO_TYPE.set(config::DEFAULT_AUDIO_TYPE).unwrap();

    // load given audio backend
    match AUDIO_TYPE.get().unwrap() {
        AudioType::Rodio => {
            // Init Rodio
            info!("Initializing Rodio audio backend.");

            match rodio::init() {
                Ok(_) => {
                    info!("Successfully initialized Rodio audio backend.");
                }
                Err(()) => {
                    error!("Failed to initialize Rodio audio backend.");

                    return Err(());
                }
            }
        }
        AudioType::Kira => {
            // Init Kira
            info!("Initializing Kira audio backend.");

            match kira::init() {
                Ok(_) => {
                    info!("Successfully initialized Kira audio backend.");
                }
                Err(_msg) => {
                    error!("Failed to initialize Kira audio backend.");

                    return Err(());
                }
            }
        }
    }

    Ok(())
}

static PLAYING_UNTIL_MS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

// extra time after playback during which the microphone is still ignored (room echo)
const PLAYBACK_TAIL_MS: u64 = 400;

fn now_ms() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

pub(crate) fn mark_playing(duration: std::time::Duration) {
    let until = now_ms() + duration.as_millis() as u64 + PLAYBACK_TAIL_MS;
    PLAYING_UNTIL_MS.fetch_max(until, std::sync::atomic::Ordering::Relaxed);
}

// true while Jarvis itself is speaking (plus a short tail)
pub fn is_playing() -> bool {
    now_ms() < PLAYING_UNTIL_MS.load(std::sync::atomic::Ordering::Relaxed)
}

pub fn play_sound(filename: &PathBuf) {
    let audio_type = match AUDIO_TYPE.get() {
        Some(t) => t,
        None => {
            warn!("Audio not initialized, cannot play: {}", filename.display());
            return;
        }
    };

    info!("Playing {}", filename.display());

    match audio_type {
        AudioType::Rodio => {
            rodio::play_sound(filename, true);
        }
        AudioType::Kira => kira::play_sound(filename),
    }
}

pub fn get_sound_directory() -> Option<PathBuf> {
    let db = DB.get()?;

    let voice_path = {
        let s = db.read();
        SOUND_DIR.join(&s.voice)
    };

    match voice_path.exists() {
        true => Some(voice_path),
        _ => {
            error!("No sounds folder found. Search path - {:?}", voice_path);
            None
        }
    }
}
