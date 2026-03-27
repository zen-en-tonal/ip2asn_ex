use ip2asn::{Builder, IpAsnMap};
use rustler::{error, Atom, Binary, NifMap, NifResult, Resource, ResourceArc};
use std::{io::Cursor, net::IpAddr};

mod atoms {
    rustler::atoms! {
        ok,
    }
}

pub struct IpAsnMapResource(IpAsnMap);

#[rustler::resource_impl]
impl Resource for IpAsnMapResource {}

type IpAsnMapResourceArc = ResourceArc<IpAsnMapResource>;

#[rustler::nif]
fn build<'a>(data: Binary<'a>) -> NifResult<(Atom, IpAsnMapResourceArc)> {
    let reader = Cursor::new(data.as_slice());
    let map = Builder::new()
        .with_source(reader)
        .map_err(map_err)?
        .build()
        .map_err(map_err)?;

    Ok((atoms::ok(), ResourceArc::new(IpAsnMapResource(map))))
}

#[rustler::nif]
fn lookup(map: IpAsnMapResourceArc, ip: String) -> NifResult<(Atom, AsnInfo)> {
    let ip = ip
        .parse::<IpAddr>()
        .map_err(|_| error::Error::Atom("invalid_ip"))?;
    let info: AsnInfo = map
        .0
        .lookup_owned(ip)
        .ok_or_else(|| error::Error::Atom("not_found"))?
        .into();

    Ok((atoms::ok(), info))
}

#[derive(Debug, Clone, PartialEq, Eq, NifMap)]
struct AsnInfo {
    pub network: String,
    pub asn: u32,
    pub country_code: String,
    pub organization: String,
}

impl From<ip2asn::AsnInfo> for AsnInfo {
    fn from(info: ip2asn::AsnInfo) -> Self {
        AsnInfo {
            network: info.network.to_string(),
            asn: info.asn,
            country_code: info.country_code.to_string(),
            organization: info.organization.to_string(),
        }
    }
}

fn map_err(error: ip2asn::Error) -> error::Error {
    match error {
        ip2asn::Error::Io(e) => error::Error::Term(Box::new(format!("IO error: {}", e))),
        ip2asn::Error::Parse {
            line_number,
            line_content,
            kind,
        } => error::Error::Term(Box::new(format!(
            "Parse error at line {}: {} (kind: {})",
            line_number, line_content, kind
        ))),
        _ => error::Error::Atom("unknown_error"),
    }
}

rustler::init!("Elixir.Ip2Asn.Nif");
