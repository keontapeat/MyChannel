import { initializeApp, getApps } from 'firebase-admin/app'
import { getFirestore } from 'firebase-admin/firestore'

// Initialize Firebase Admin using Application Default Credentials
// This works when you're logged in with `firebase login`
if (!getApps().length) {
  try {
    initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID || 'mychannel-ca26d'
    })
    console.log('✅ Firebase Admin initialized (using firebase login)')
  } catch (err) {
    console.error('❌ Firebase initialization failed:', err.message)
    throw err
  }
}

export const db = getFirestore()

export async function query(text, params = []) {
  const start = Date.now()
  const result = await executeFirestoreQuery(text, params)
  const ms = Date.now() - start
  if (process.env.LOG_SQL === '1') console.log('[firestore]', ms + 'ms', text)
  return result
}

async function executeFirestoreQuery(sql, params) {
  const sqlLower = sql.toLowerCase().trim()
  
  if (sqlLower.startsWith('insert into')) {
    return await handleInsert(sql, params)
  }
  if (sqlLower.startsWith('select')) {
    return await handleSelect(sql, params)
  }
  if (sqlLower.startsWith('update')) {
    return await handleUpdate(sql, params)
  }
  if (sqlLower.startsWith('delete')) {
    return await handleDelete(sql, params)
  }
  if (sqlLower.startsWith('alter table') || sqlLower.startsWith('create table')) {
    console.log('[firestore] Skipping schema operation (Firestore is schemaless)')
    return { rows: [], rowCount: 0 }
  }
  
  throw new Error(`Unsupported SQL query: ${sql.substring(0, 50)}...`)
}

async function handleInsert(sql, params) {
  const tableMatch = sql.match(/insert\s+into\s+(\w+)/i)
  if (!tableMatch) throw new Error('Could not parse table name')
  
  const tableName = tableMatch[1]
  const returningMatch = sql.match(/returning\s+(\w+)/i)
  const returningField = returningMatch ? returningMatch[1] : null
  
  const columnsMatch = sql.match(/\(([^)]+)\)\s*values/i)
  if (!columnsMatch) throw new Error('Could not parse columns')
  
  const columns = columnsMatch[1].split(',').map(c => c.trim())
  const data = {}
  columns.forEach((col, i) => {
    if (params[i] !== undefined && params[i] !== null) {
      data[col] = params[i]
    }
  })
  
  if (!data.created_at && columns.includes('created_at')) {
    data.created_at = new Date()
  }
  
  const onConflictMatch = sql.match(/on\s+conflict\s*\(([^)]+)\)\s*do\s+update\s+set\s+(.+?)(?:where|returning|$)/is)
  if (onConflictMatch) {
    const conflictKey = onConflictMatch[1].trim()
    const conflictValue = data[conflictKey]
    
    if (conflictValue) {
      const snapshot = await db.collection(tableName).where(conflictKey, '==', conflictValue).limit(1).get()
      if (!snapshot.empty) {
        const docRef = snapshot.docs[0].ref
        await docRef.update(data)
        const updated = await docRef.get()
        const resultData = { id: updated.id, ...updated.data() }
        return { rows: [resultData], rowCount: 1 }
      }
    }
  }
  
  const docRef = await db.collection(tableName).add(data)
  const created = await docRef.get()
  const resultData = { id: created.id, ...created.data() }
  
  if (returningField) {
    return { rows: [{ [returningField]: resultData.id }], rowCount: 1 }
  }
  
  return { rows: [resultData], rowCount: 1 }
}

async function handleSelect(sql, params) {
  const tableMatch = sql.match(/from\s+(\w+)/i)
  if (!tableMatch) throw new Error('Could not parse table name')
  
  const tableName = tableMatch[1]
  let query = db.collection(tableName)
  
  const whereMatch = sql.match(/where\s+(.+?)(?:order\s+by|limit|$)/is)
  if (whereMatch) {
    const whereClause = whereMatch[1].trim()
    const conditions = whereClause.split(/\s+and\s+/i)
    
    conditions.forEach((condition) => {
      const eqMatch = condition.match(/(\w+)\s*=\s*\$(\d+)/)
      if (eqMatch) {
        const field = eqMatch[1]
        const paramIdx = parseInt(eqMatch[2]) - 1
        if (params[paramIdx] !== undefined) {
          query = query.where(field, '==', params[paramIdx])
        }
      }
    })
  }
  
  const orderMatch = sql.match(/order\s+by\s+(\w+)(?:\s+(asc|desc))?/i)
  if (orderMatch) {
    const field = orderMatch[1]
    const direction = orderMatch[2]?.toLowerCase() === 'desc' ? 'desc' : 'asc'
    query = query.orderBy(field, direction)
  }
  
  const limitMatch = sql.match(/limit\s+(\d+)/i)
  if (limitMatch) {
    query = query.limit(parseInt(limitMatch[1]))
  }
  
  const snapshot = await query.get()
  const rows = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }))
  
  return { rows, rowCount: rows.length }
}

async function handleUpdate(sql, params) {
  const tableMatch = sql.match(/update\s+(\w+)/i)
  if (!tableMatch) throw new Error('Could not parse table name')
  
  const tableName = tableMatch[1]
  const setMatch = sql.match(/set\s+(.+?)(?:where|$)/is)
  if (!setMatch) throw new Error('Could not parse SET clause')
  
  const updates = {}
  const setClause = setMatch[1].trim()
  const assignments = setClause.split(',')
  
  let paramIdx = 0
  assignments.forEach(assignment => {
    const match = assignment.match(/(\w+)\s*=\s*(?:\$\d+|coalesce\([^)]+\)|now\(\))/)
    if (match) {
      const field = match[1].trim()
      if (assignment.includes('now()')) {
        updates[field] = new Date()
      } else if (assignment.includes('coalesce')) {
        if (params[paramIdx] !== null && params[paramIdx] !== undefined) {
          updates[field] = params[paramIdx]
        }
        paramIdx++
      } else {
        updates[field] = params[paramIdx++]
      }
    }
  })
  
  const whereMatch = sql.match(/where\s+(.+?)$/is)
  if (!whereMatch) {
    throw new Error('UPDATE without WHERE not supported')
  }
  
  const whereClause = whereMatch[1].trim()
  const fieldMatch = whereClause.match(/(\w+)\s*=\s*\$(\d+)/)
  
  if (fieldMatch) {
    const field = fieldMatch[1]
    const paramIndex = parseInt(fieldMatch[2]) - 1
    const value = params[paramIndex]
    
    const snapshot = await db.collection(tableName).where(field, '==', value).get()
    const batch = db.batch()
    snapshot.docs.forEach(doc => {
      batch.update(doc.ref, updates)
    })
    await batch.commit()
    return { rows: [], rowCount: snapshot.size }
  }
  
  throw new Error('Could not parse WHERE clause')
}

async function handleDelete(sql, params) {
  const tableMatch = sql.match(/delete\s+from\s+(\w+)/i)
  if (!tableMatch) throw new Error('Could not parse table name')
  
  const tableName = tableMatch[1]
  const whereMatch = sql.match(/where\s+(.+?)$/is)
  if (!whereMatch) {
    throw new Error('DELETE without WHERE not supported')
  }
  
  const whereClause = whereMatch[1].trim()
  const fieldMatch = whereClause.match(/(\w+)\s*=\s*\$(\d+)/)
  
  if (fieldMatch) {
    const field = fieldMatch[1]
    const paramIndex = parseInt(fieldMatch[2]) - 1
    const value = params[paramIndex]
    
    const snapshot = await db.collection(tableName).where(field, '==', value).get()
    const batch = db.batch()
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref)
    })
    await batch.commit()
    return { rows: [], rowCount: snapshot.size }
  }
  
  throw new Error('Could not parse WHERE clause')
}
