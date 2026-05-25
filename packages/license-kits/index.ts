export type LicenseCode = 'CC0'|'PD'|'CC_BY'|'OTHER'

export function allowsCommercial(code: LicenseCode): boolean {
  return code === 'CC0' || code === 'PD' || code === 'CC_BY'
}

export function requiresAttribution(code: LicenseCode): boolean {
  return code === 'CC_BY'
}

export function attributionText(code: LicenseCode, params: { author?: string, source?: string, licenseUrl?: string, version?: string }): string {
  switch (code) {
    case 'CC0':
      return `Video courtesy of ${params.author ?? 'author'} via ${params.source ?? 'source'}. License: CC0.`
    case 'PD':
      return `Public Domain footage via ${params.source ?? 'source'}.`
    case 'CC_BY':
      return `© ${params.author ?? 'author'} via ${params.source ?? 'source'}, licensed under CC BY ${params.version ?? ''}. Link: ${params.licenseUrl ?? ''}.`
    default:
      return ''
  }
}

export function attributionHtml(code: LicenseCode, params: { author?: string, source?: string, licenseUrl?: string, version?: string }): string {
  const t = attributionText(code, params)
  return `<p>${t}</p>`
}



