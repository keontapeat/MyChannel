// Try to use Firestore, fall back to mock if credentials unavailable
let db, query

const useMock = async () => {
  console.warn('⚠️  Firestore unavailable, using mock database')
  const mock = await import('./db-mock.js')
  return { db: mock.db, query: mock.query }
}

try {
  const firestore = await import('./db-firestore.js')
  // Test if Firestore is actually working
  try {
    await firestore.db.collection('_test').limit(1).get()
    db = firestore.db
    query = firestore.query
    console.log('✅ Using Firestore')
  } catch (err) {
    const mock = await useMock()
    db = mock.db
    query = mock.query
  }
} catch (err) {
  const mock = await useMock()
  db = mock.db
  query = mock.query
}

export { db, query }
