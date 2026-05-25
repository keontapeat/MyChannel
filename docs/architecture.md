## MyChannel Architecture (E2E)

```mermaid
flowchart TD
  subgraph Client
    iOS[iOS App (SwiftUI)]
    Web[Web/TV]
  end

  subgraph Firebase
    Auth[Auth]
    Firestore[Firestore]
    Storage[Storage]
    Functions[2nd Gen Functions]
    FCM[FCM]
    RC[Remote Config]
  end

  subgraph GCP
    RunUpload[Cloud Run: Upload]
    RunContent[Cloud Run: Content]
    RunTranscode[Cloud Run: Transcode]
    RunEvents[Cloud Run: Events]
    PubSub[Pub/Sub]
    BQ[BigQuery]
    Secret[Secret Manager]
    CDN[Cloud CDN + Backend Bucket]
    APIgw[API Gateway]
  end

  iOS -->|Auth, FCM| Auth
  iOS -->|Queries, Realtime| Firestore
  iOS -->|Media read/write| Storage
  iOS -->|Rules-guarded HTTP| Functions

  Functions -->|Signed URLs| Storage
  Functions -->|Triggers| Firestore
  Functions -->|Ads Proxy| RunContent
  Functions -->|Growth/Referrals| Firestore

  iOS -->|Upload signedUrl| RunUpload
  RunUpload --> Storage

  Firestore -->|trigger: uploads| Functions
  Functions -->|enqueue| PubSub
  PubSub --> RunTranscode
  RunTranscode --> Storage
  RunTranscode --> Firestore

  Storage --> CDN
  iOS -->|HLS via CDN| CDN

  iOS -->|Events| RunEvents
  RunEvents --> PubSub
  PubSub --> BQ

  APIgw --> RunUpload
  APIgw --> RunContent
  APIgw --> RunEvents

  Secret --> RunUpload
  Secret --> RunContent
  Secret --> Functions
```

- Upload → signed PUT to ingest bucket; finalize → Transcoder job; write status + thumbnails.
- Serve → Cloud CDN signed URLs; cache control optimized; optional DRM later.
- Ads → client requests `/ads/serve` via proxy; VMAP supported; OpenRTB to partners.
- Analytics → events to Pub/Sub; BQ tables for plays/impressions/likes; GA4 export enabled.
