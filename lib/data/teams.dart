// ─────────────────────────────────────────────────────────────────
// Curated pick-lists for registration: clubs (with crests) and
// national teams (with flags). All image URLs were verified to resolve.
//
// Club crests: ESPN CDN — a.espncdn.com/i/teamlogos/soccer/500/<id>.png
// National flags: flagcdn.com/w160/<iso>.png
//
// Clubs ESPN doesn't host a crest for (e.g. Zamalek) carry logoUrl == null;
// the picker falls back to a colored monogram badge.
// ─────────────────────────────────────────────────────────────────

class Club {
  final String name;
  final String? logoUrl; // null -> monogram fallback
  const Club(this.name, this.logoUrl);
}

class NationalTeam {
  final String name;
  final String flagUrl;
  const NationalTeam(this.name, this.flagUrl);
}

String _crest(int id) => 'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png';
String _flag(String iso) => 'https://flagcdn.com/w160/$iso.png';

/// Supported clubs, grouped loosely by league for a sensible order.
const List<Club> kClubs = [
  // Premier League
  Club('Liverpool', 'https://a.espncdn.com/i/teamlogos/soccer/500/364.png'),
  Club('Manchester United', 'https://a.espncdn.com/i/teamlogos/soccer/500/360.png'),
  Club('Manchester City', 'https://a.espncdn.com/i/teamlogos/soccer/500/382.png'),
  Club('Arsenal', 'https://a.espncdn.com/i/teamlogos/soccer/500/359.png'),
  Club('Chelsea', 'https://a.espncdn.com/i/teamlogos/soccer/500/363.png'),
  Club('Tottenham Hotspur', 'https://a.espncdn.com/i/teamlogos/soccer/500/367.png'),
  Club('Newcastle United', 'https://a.espncdn.com/i/teamlogos/soccer/500/361.png'),
  Club('Aston Villa', 'https://a.espncdn.com/i/teamlogos/soccer/500/362.png'),
  Club('West Ham United', 'https://a.espncdn.com/i/teamlogos/soccer/500/371.png'),
  Club('Everton', 'https://a.espncdn.com/i/teamlogos/soccer/500/368.png'),
  // La Liga
  Club('Real Madrid', 'https://a.espncdn.com/i/teamlogos/soccer/500/86.png'),
  Club('Barcelona', 'https://a.espncdn.com/i/teamlogos/soccer/500/83.png'),
  Club('Atlético Madrid', 'https://a.espncdn.com/i/teamlogos/soccer/500/1068.png'),
  // Bundesliga
  Club('Bayern Munich', 'https://a.espncdn.com/i/teamlogos/soccer/500/132.png'),
  Club('Borussia Dortmund', 'https://a.espncdn.com/i/teamlogos/soccer/500/124.png'),
  // Serie A
  Club('Juventus', 'https://a.espncdn.com/i/teamlogos/soccer/500/111.png'),
  Club('AC Milan', 'https://a.espncdn.com/i/teamlogos/soccer/500/103.png'),
  Club('Inter Milan', 'https://a.espncdn.com/i/teamlogos/soccer/500/110.png'),
  Club('Napoli', 'https://a.espncdn.com/i/teamlogos/soccer/500/114.png'),
  // Ligue 1
  Club('Paris Saint-Germain', 'https://a.espncdn.com/i/teamlogos/soccer/500/160.png'),
  // Egypt
  Club('Al Ahly', 'https://a.espncdn.com/i/teamlogos/soccer/500/10207.png'),
  Club('Zamalek', null),
  Club('Pyramids FC', null),
  // Saudi Pro League
  Club('Al Hilal', 'https://a.espncdn.com/i/teamlogos/soccer/500/929.png'),
  Club('Al Nassr', 'https://a.espncdn.com/i/teamlogos/soccer/500/817.png'),
  Club('Al Ittihad', 'https://a.espncdn.com/i/teamlogos/soccer/500/2276.png'),
  Club('Al Ahli (SA)', 'https://a.espncdn.com/i/teamlogos/soccer/500/8346.png'),
];

/// Supported national teams. flagcdn covers every ISO 3166 code, plus the
/// special UK constituent codes (gb-eng, gb-sct, gb-wls).
const List<NationalTeam> kNationalTeams = [
  NationalTeam('Egypt', 'https://flagcdn.com/w160/eg.png'),
  NationalTeam('Morocco', 'https://flagcdn.com/w160/ma.png'),
  NationalTeam('Algeria', 'https://flagcdn.com/w160/dz.png'),
  NationalTeam('Tunisia', 'https://flagcdn.com/w160/tn.png'),
  NationalTeam('Senegal', 'https://flagcdn.com/w160/sn.png'),
  NationalTeam('Nigeria', 'https://flagcdn.com/w160/ng.png'),
  NationalTeam('Ghana', 'https://flagcdn.com/w160/gh.png'),
  NationalTeam('Cameroon', 'https://flagcdn.com/w160/cm.png'),
  NationalTeam('Saudi Arabia', 'https://flagcdn.com/w160/sa.png'),
  NationalTeam('Qatar', 'https://flagcdn.com/w160/qa.png'),
  NationalTeam('Brazil', 'https://flagcdn.com/w160/br.png'),
  NationalTeam('Argentina', 'https://flagcdn.com/w160/ar.png'),
  NationalTeam('Uruguay', 'https://flagcdn.com/w160/uy.png'),
  NationalTeam('Colombia', 'https://flagcdn.com/w160/co.png'),
  NationalTeam('Mexico', 'https://flagcdn.com/w160/mx.png'),
  NationalTeam('United States', 'https://flagcdn.com/w160/us.png'),
  NationalTeam('France', 'https://flagcdn.com/w160/fr.png'),
  NationalTeam('Germany', 'https://flagcdn.com/w160/de.png'),
  NationalTeam('Spain', 'https://flagcdn.com/w160/es.png'),
  NationalTeam('Italy', 'https://flagcdn.com/w160/it.png'),
  NationalTeam('Portugal', 'https://flagcdn.com/w160/pt.png'),
  NationalTeam('England', 'https://flagcdn.com/w160/gb-eng.png'),
  NationalTeam('Netherlands', 'https://flagcdn.com/w160/nl.png'),
  NationalTeam('Belgium', 'https://flagcdn.com/w160/be.png'),
  NationalTeam('Croatia', 'https://flagcdn.com/w160/hr.png'),
  NationalTeam('Switzerland', 'https://flagcdn.com/w160/ch.png'),
  NationalTeam('Denmark', 'https://flagcdn.com/w160/dk.png'),
  NationalTeam('Poland', 'https://flagcdn.com/w160/pl.png'),
  NationalTeam('Japan', 'https://flagcdn.com/w160/jp.png'),
  NationalTeam('South Korea', 'https://flagcdn.com/w160/kr.png'),
];

// Kept for reference / future programmatic additions.
// ignore: unused_element
String clubCrest(int espnId) => _crest(espnId);
// ignore: unused_element
String countryFlag(String iso2) => _flag(iso2);
