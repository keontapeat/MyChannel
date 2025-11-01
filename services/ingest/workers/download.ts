import fs from 'fs'
import path from 'path'
import https from 'https'

export async function downloadToLocal(url: string, outDir: string, outName: string): Promise<string> {
  await fs.promises.mkdir(outDir, { recursive: true })
  const dest = path.join(outDir, outName)
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest)
    https.get(url, res => {
      if (res.statusCode && res.statusCode >= 400) { reject(new Error(`HTTP ${res.statusCode}`)); return }
      res.pipe(file)
      file.on('finish', () => file.close(()=>resolve(dest)))
    }).on('error', err => reject(err))
  })
}

export async function uploadToGCS(localPath: string, gcsUri: string) {
  // TODO: integrate @google-cloud/storage. Mocked in dev when GOOGLE_APPLICATION_CREDENTIALS missing
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return { uri: gcsUri, mocked: true }
  }
  return { uri: gcsUri }
}



