# Rules Unit Tests (Scaffold)

Use the Firebase Emulator Suite to run Firestore and Storage rules tests.

- Install deps: npm i -D @firebase/rules-unit-testing
- Example tests to add:
  - users can update own profile only
  - playlists: owner-only write, public read
  - videos: adSettings protected from non-admin
  - storage: only owner can write to their video paths

Add test files under this directory using Node/Jest or Vitest.
