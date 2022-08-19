pub mod createroot;
pub mod genpkey;
pub mod init;
pub mod newcrl;
pub mod signsubca;
pub mod yubikey;

use clap::{AppSettings, Parser};
use createroot::create_root;
use genpkey::genpkey;
use init::init_cadata;
use newcrl::new_crl;
use signsubca::sign_subca;

const HOSTCONFIG: &'static [u8] = include_bytes!("hostconfig.sh");

fn main() -> Result<(), ()> {
    match Cmd::parse() {
        Cmd::GetHostconfig => {
            println!("{}", String::from_utf8_lossy(HOSTCONFIG));
            Ok(())
        }
        Cmd::Genpkey(c) => genpkey(c),
        Cmd::Init(c) => init_cadata(c),
        Cmd::CreateRoot(c) => create_root(c),
        Cmd::NewCrl(c) => new_crl(c),
        Cmd::SignSubca(c) => sign_subca(c),
        Cmd::Yubikey(c) => match c {
            YubikeyCmd::NewSecrets(c) => yubikey::new_secrets(c),
            YubikeyCmd::SetSecrets(c) => yubikey::set_secrets(c),
            YubikeyCmd::OTP(c) => yubikey::otp(c),
            YubikeyCmd::Serial(c) => yubikey::serial(c),
            YubikeyCmd::ImportKey(c) => yubikey::import_key(c),
        },
    }
}

/// Lab Root Certificate Authority initialization and management
#[derive(Debug, Parser)]
#[clap(version)]
#[clap(global_setting(AppSettings::DeriveDisplayOrder))]
#[clap(global_setting(AppSettings::ArgRequiredElseHelp))]
#[clap(disable_help_subcommand = true)]
pub enum Cmd {
    /// Print the hostconfig script
    GetHostconfig,

    /// Generate private key
    Genpkey(GenpkeyConfig),

    /// Initialize CA data
    Init(InitConfig),

    /// Create self-signed Root Certificate
    CreateRoot(CreateRootConfig),

    /// Create new Certificate Revocation List
    NewCrl(NewCrlConfig),

    /// Sign a new Subordinate Certificate Signing Request
    SignSubca(SignSubcaConfig),

    /// Yubikey configuration commands
    #[clap(subcommand)]
    Yubikey(YubikeyCmd),
}

#[derive(Debug, Parser)]
pub enum YubikeyCmd {
    /// Generate new Management Key, PIV PIN, and PIN Unlock Key
    NewSecrets(YubikeyNewSecretsConfig),

    /// Set Secrets on Yubikey device
    SetSecrets(YubikeySetSecretsConfig),

    /// Configure One-Time-Password application
    OTP(YubikeyEnableDisableConfig),

    /// Configure serial number visibility
    Serial(YubikeyEnableDisableConfig),

    /// Import PIV key
    ImportKey(YubikeyImportKeyConfig),
}

#[derive(Debug, Parser)]
pub struct YubikeyEnableDisableConfig {
    #[clap(possible_values=&["enable","disable"])]
    pub state: String,
}

#[derive(Debug, Parser)]
pub struct YubikeyNewSecretsConfig {
    /// Directory to save secrets
    pub directory: String,
}

#[derive(Debug, Parser)]
pub struct YubikeySetSecretsConfig {
    /// Management Key
    #[clap(short, long)]
    pub key: String,

    /// PIV PIN
    #[clap(short = 'p', long)]
    pub pin: String,

    /// PIN Unlock Key
    #[clap(short = 'u', long)]
    pub puk: String,
}

#[derive(Debug, Parser)]
pub struct YubikeyImportKeyConfig {
    /// PIV slot to install key
    #[clap(short, long, required = true)]
    pub slot: String,

    /// Private key file
    #[clap(short, long, required = true)]
    pub key: String,

    /// Yubikey Managment key file
    #[clap(short, long, required = true)]
    pub mgmt: String,

    /// PIV PIN file
    #[clap(short, long, required = true)]
    pub pin: String,
}

#[derive(Debug, Parser)]
pub struct InitConfig {
    /// CA data directory
    #[clap(short, long)]
    #[clap(value_name = "DIR")]
    pub directory: String,

    /// Authority Info Access; URL of published certificate
    #[clap(short, long)]
    pub aia: String,

    /// CRL Distribution Point; URL of published CRL
    #[clap(short, long)]
    pub cdp: String,

    /// Private key file (if not using Yubikey)
    #[clap(long)]
    pub key: String,

    /// Use a Yubikey for CA key and Certificate storage
    #[clap(long)]
    pub yubikey: bool,

    /// PIV slot the private key will be stored
    #[clap(short, long)]
    #[clap(possible_values = &["9a", "9c"])]
    pub slot: String,
}

#[derive(Debug, Parser)]
pub struct GenpkeyConfig {
    /// Private key algorithm
    #[clap(short, long)]
    #[clap(possible_values = &["ec","rsa"])]
    #[clap(required = true)]
    pub algorithm: String,

    /// Length of the key in bits.
    #[clap(short, long)]
    #[clap(possible_values = &["256","384","1024","2048"])]
    #[clap(required = true)]
    pub length: u8,

    /// Do not encrypt private with a passphrase
    #[clap(long)]
    pub no_crypt: bool,

    /// Output encrypted key in PKCS#8 format instead of PKCS#1
    #[clap(long)]
    pub pkcs8: bool,

    /// Output file location
    #[clap(short, long)]
    pub out: String,

    /// Generate private key on Yubikey device
    #[clap(long)]
    pub yubikey: bool,

    /// Yubikey slot to generate the key
    #[clap(short, long)]
    #[clap(possible_values = &["9a","9c"])]
    pub slot: String,

    /// Yubikey Management Key file
    #[clap(short, long)]
    pub mgmt: String,

    /// Yubikey PIV PIN file
    #[clap(short, long)]
    pub pin: String,
}

#[derive(Debug, Parser)]
pub struct CreateRootConfig {
    /// Root CA data directory (defaults to $ROOTCA_DIR)
    #[clap(short, long)]
    #[clap(value_name = "DIR")]
    pub directory: String,

    // Root Certificate Subject, OpenSSL formatted
    #[clap(short = 'S', long)]
    #[clap(required = true)]
    pub subject: String,

    /// Number of years Root Certificate is valid for
    #[clap(short, long)]
    #[clap(required = true)]
    pub years: u8,

    /// Private key file (incompatible with '--yubikey')
    #[clap(short, long)]
    pub key: String,

    /// Private key passphrase (required with '-k,--key'); See
    /// 'openssl-passphrase-options'; Only 'file', 'fd', and 'stdin' accepted
    #[clap(short = 'P', long)]
    pub passin: String,

    /// Use Yubikey device (incompatible with '-k,--key')
    #[clap(long)]
    pub yubikey: bool,

    /// Yubikey PIV slot (required with '--yubikey')
    #[clap(short, long)]
    #[clap(possible_values = &["9a","9c"])]
    pub slot: String,

    /// Yubikey PIV PIN file (required with '--yubikey')
    #[clap(short, long)]
    pub pin: String,

    /// Install certificate to Yubikey slot
    #[clap(long)]
    pub install: bool,

    /// Yubikey Management Key file (required with '--install')
    #[clap(short, long)]
    pub mgmt: String,
}

#[derive(Debug, Parser)]
pub struct NewCrlConfig {
    /// Root CA data directory (defaults to $ROOTCA_DIR)
    #[clap(short, long)]
    #[clap(value_name = "DIR")]
    pub directory: String,

    /// Private key passphrase; See 'openssl-passphrase-options'; Only 'file',
    /// 'fd', and 'stdin' accepted
    #[clap(short = 'P', long)]
    pub passin: String,

    /// Use Yubikey device
    #[clap(short, long)]
    pub yubikey: bool,

    /// Yubikey PIV PIN (required with '--yubikey')
    #[clap(short, long)]
    pub pin: String,
}

#[derive(Debug, Parser)]
pub struct SignSubcaConfig {
    /// Root CA data directory (defaults to $ROOTCA_DIR)
    #[clap(short, long)]
    #[clap(value_name = "DIR")]
    pub directory: String,

    /// Private key passphrase; See 'openssl-passphrase-options'; Only 'file',
    /// 'fd', and 'stdin' accepted
    #[clap(short = 'P', long)]
    pub passin: String,

    /// File to read Certificate Signing Request from
    #[clap(short, long)]
    pub csr: String,

    /// File to write signed Certificate to
    #[clap(short, long)]
    pub out: String,

    /// Use Yubikey device
    #[clap(short, long)]
    pub yubikey: bool,

    /// Yubikey PIV PIN (required with '--yubikey')
    #[clap(short, long)]
    pub pin: String,
}
