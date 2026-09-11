# releases

Build sideload dell'app iOS `1r0-pkm` (ADR-0027: piano gratuito Apple,
distribuzione via SideStore/AltStore).

Gli `.ipa` qui sono **non firmati**: SideStore/AltStore li ri-firma con il tuo
Apple ID all'installazione (bundle id → `dev.1r0.pkm.<team>`, ri-firma ~ogni
7 giorni). Nessun profilo di provisioning nel repo.

| file | versione | commit | contenuto | note |
|---|---|---|---|---|
| ~~`1r0-pkm-1.0-20260910.ipa`~~ | 1.0 (1) | `8004b92` | gym + diet | **rimossa**, superata. |
| ~~`1r0-pkm-1.0-20260911.ipa`~~ | 1.0 (2) | `fc52de5` | gym + diet + dieta a template/toggle Salute (ADR-0029) + dashboard grafici Palestra (ADR-0030) | **rimossa**: creare un template crashava sempre (fix sotto). |
| `1r0-pkm-1.0-20260911-b3.ipa` | 1.0 (3) | `7673379` | gym + diet + dieta a template/toggle Salute + dashboard grafici Palestra + fix crash creazione template + tab Impostazioni al posto di Progressi (ADR-0031) | beta. HealthKit non verificato su device; backend HTTP (`100.31.154.129`), niente HTTPS. |

## Come è stato prodotto

```bash
export DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer"
cd apps/ios/1r0-pkm
xcodebuild archive -scheme 1r0-pkm -configuration Release \
  -destination 'generic/platform=iOS' -archivePath /tmp/1r0-pkm.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
mkdir Payload && cp -R /tmp/1r0-pkm.xcarchive/Products/Applications/1r0-pkm.app Payload/
zip -qry 1r0-pkm-<ver>.ipa Payload && rm -rf Payload
```

## Stato test alla build

- unit `1r0-pkmTests`: 78/78
- `1r0-pkmUITests`: 19/19 (Xcode-beta 15.4, iPhone 15 / iOS 17.5)
