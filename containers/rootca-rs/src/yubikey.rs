use crate::{
    YubikeyEnableDisableConfig, YubikeyImportKeyConfig, YubikeyNewSecretsConfig,
    YubikeySetSecretsConfig,
};

pub fn new_secrets(_config: YubikeyNewSecretsConfig) -> Result<(), ()> {
    println!("yubikey new_secrets");
    Ok(())
}

pub fn set_secrets(_config: YubikeySetSecretsConfig) -> Result<(), ()> {
    println!("yubikey set_secrets");
    Ok(())
}

pub fn otp(_config: YubikeyEnableDisableConfig) -> Result<(), ()> {
    println!("yubikey otp toggle");
    Ok(())
}

pub fn serial(_config: YubikeyEnableDisableConfig) -> Result<(), ()> {
    println!("yubikey serial toggle");
    Ok(())
}

pub fn import_key(_config: YubikeyImportKeyConfig) -> Result<(), ()> {
    println!("yubikey import_key");
    Ok(())
}
