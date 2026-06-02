/**
 * ddex.ts — DDEX ERN (Electronic Release Notification) feed generation.
 *
 * Generates a standards-compliant ERN 4.3 NewReleaseMessage XML for a release,
 * which is the format DSPs (Spotify, Apple, Amazon, etc.) and aggregators
 * consume to ingest music. This is the real delivery payload — pair it with the
 * deliver() adapter in aggregator.ts to push to your distribution partner or
 * directly to a DSP that has granted you a DDEX party id.
 *
 * Notes:
 *   • Audio + image resources are referenced by their storage URLs; a real
 *     delivery also ships the binary files alongside this XML in a batch
 *     (SFTP/cloud bucket). deliver() handles that hand-off.
 *   • Party identifiers (DPID) must be issued by DDEX. Set MYCHANNEL_DPID.
 */

const MYCHANNEL_DPID = process.env.MYCHANNEL_DPID || 'PADPIDA0000000000Z'; // REPLACE with your DDEX Party ID
const MYCHANNEL_SENDER_NAME = process.env.MYCHANNEL_SENDER_NAME || 'MyChannel Music';

export interface DDEXContributor {
  name: string;
  role: string; // e.g. MainArtist, Producer, Composer, Lyricist
}

export interface DDEXTrack {
  trackId: string;
  isrc: string;
  title: string;
  durationSeconds: number;
  artistName: string;
  contributors?: DDEXContributor[];
  genre?: string;
  isExplicit?: boolean;
  audioURL: string;
  trackNumber: number;
  pLineYear?: string;
  pLineText?: string;
}

export interface DDEXRelease {
  releaseId: string;
  upc: string;
  title: string;
  displayArtist: string;
  releaseType: 'Album' | 'EP' | 'Single';
  genre?: string;
  label?: string;
  cLineYear?: string;
  cLineText?: string;
  pLineYear?: string;
  pLineText?: string;
  releaseDate: string; // ISO yyyy-mm-dd
  artworkURL: string;
  tracks: DDEXTrack[];
}

function esc(value: string | undefined): string {
  if (!value) return '';
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function isoDuration(seconds: number): string {
  const s = Math.max(0, Math.round(seconds || 0));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  return `PT${h ? h + 'H' : ''}${m ? m + 'M' : ''}${sec}S`;
}

/** Build a DDEX ERN 4.3 NewReleaseMessage for a release. */
export function buildERNMessage(release: DDEXRelease): string {
  const messageId = `MCH_${release.releaseId}_${Date.now()}`;
  const createdAt = new Date().toISOString();

  const soundRecordings = release.tracks
    .map((t, idx) => {
      const resourceRef = `A${idx + 1}`;
      const contributors = (t.contributors || [])
        .map(
          (c) => `
          <Contributor>
            <PartyName><FullName>${esc(c.name)}</FullName></PartyName>
            <Role>${esc(c.role)}</Role>
          </Contributor>`
        )
        .join('');
      return `
      <SoundRecording>
        <ResourceReference>${resourceRef}</ResourceReference>
        <Type>MusicalWorkSoundRecording</Type>
        <ResourceId><ISRC>${esc(t.isrc.replace(/-/g, ''))}</ISRC></ResourceId>
        <ReferenceTitle><TitleText>${esc(t.title)}</TitleText></ReferenceTitle>
        <Duration>${isoDuration(t.durationSeconds)}</Duration>
        <DisplayArtist>
          <PartyName><FullName>${esc(t.artistName)}</FullName></PartyName>
          <ArtistRole>MainArtist</ArtistRole>
        </DisplayArtist>${contributors}
        <ParentalWarningType>${t.isExplicit ? 'Explicit' : 'NotExplicit'}</ParentalWarningType>
        <PLine><Year>${esc(t.pLineYear || String(new Date().getFullYear()))}</Year><PLineText>${esc(
        t.pLineText || t.artistName
      )}</PLineText></PLine>
        <TechnicalDetails>
          <TechnicalResourceDetailsReference>T${idx + 1}</TechnicalResourceDetailsReference>
          <DeliveryFile>
            <Type>AudioFile</Type>
            <File><URI>${esc(t.audioURL)}</URI></File>
          </DeliveryFile>
        </TechnicalDetails>
      </SoundRecording>`;
    })
    .join('');

  const imageResource = `
      <Image>
        <ResourceReference>IMG1</ResourceReference>
        <Type>FrontCoverImage</Type>
        <ResourceId><ProprietaryId Namespace="MyChannel">${esc(release.releaseId)}_cover</ProprietaryId></ResourceId>
        <TechnicalDetails>
          <TechnicalResourceDetailsReference>TIMG1</TechnicalResourceDetailsReference>
          <DeliveryFile>
            <Type>Image</Type>
            <File><URI>${esc(release.artworkURL)}</URI></File>
          </DeliveryFile>
        </TechnicalDetails>
      </Image>`;

  const resourceGroupItems = release.tracks
    .map(
      (t, idx) => `
        <ResourceGroupContentItem>
          <SequenceNumber>${t.trackNumber || idx + 1}</SequenceNumber>
          <ReleaseResourceReference>A${idx + 1}</ReleaseResourceReference>
        </ResourceGroupContentItem>`
    )
    .join('');

  return `<?xml version="1.0" encoding="UTF-8"?>
<ern:NewReleaseMessage xmlns:ern="http://ddex.net/xml/ern/43" MessageSchemaVersionId="ern/43" LanguageAndScriptCode="en">
  <MessageHeader>
    <MessageId>${esc(messageId)}</MessageId>
    <MessageSender>
      <PartyId>${esc(MYCHANNEL_DPID)}</PartyId>
      <PartyName><FullName>${esc(MYCHANNEL_SENDER_NAME)}</FullName></PartyName>
    </MessageSender>
    <MessageRecipient>
      <PartyId>PADPIDA-RECIPIENT</PartyId>
    </MessageRecipient>
    <MessageCreatedDateTime>${createdAt}</MessageCreatedDateTime>
  </MessageHeader>
  <ResourceList>${soundRecordings}${imageResource}
  </ResourceList>
  <ReleaseList>
    <Release>
      <ReleaseReference>R0</ReleaseReference>
      <ReleaseType>${esc(release.releaseType)}</ReleaseType>
      <ReleaseId><ICPN>${esc(release.upc)}</ICPN></ReleaseId>
      <DisplayTitleText>${esc(release.title)}</DisplayTitleText>
      <DisplayArtist>
        <PartyName><FullName>${esc(release.displayArtist)}</FullName></PartyName>
        <ArtistRole>MainArtist</ArtistRole>
      </DisplayArtist>
      <LabelName>${esc(release.label || MYCHANNEL_SENDER_NAME)}</LabelName>
      <Genre><GenreText>${esc(release.genre || 'Pop')}</GenreText></Genre>
      <PLine><Year>${esc(release.pLineYear || String(new Date().getFullYear()))}</Year><PLineText>${esc(
    release.pLineText || release.displayArtist
  )}</PLineText></PLine>
      <CLine><Year>${esc(release.cLineYear || String(new Date().getFullYear()))}</Year><CLineText>${esc(
    release.cLineText || release.label || release.displayArtist
  )}</CLineText></CLine>
      <ResourceGroup>${resourceGroupItems}
        <LinkedResourceReference>IMG1</LinkedResourceReference>
      </ResourceGroup>
    </Release>
  </ReleaseList>
  <DealList>
    <ReleaseDeal>
      <DealReleaseReference>R0</DealReleaseReference>
      <Deal>
        <DealTerms>
          <CommercialModelType>SubscriptionModel</CommercialModelType>
          <CommercialModelType>AdvertisementSupportedModel</CommercialModelType>
          <Usage><UseType>OnDemandStream</UseType><UseType>PermanentDownload</UseType></Usage>
          <TerritoryCode>Worldwide</TerritoryCode>
          <ValidityPeriod><StartDate>${esc(release.releaseDate)}</StartDate></ValidityPeriod>
        </DealTerms>
      </Deal>
    </ReleaseDeal>
  </DealList>
</ern:NewReleaseMessage>`;
}
