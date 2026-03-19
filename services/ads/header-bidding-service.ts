/**
 * Header Bidding Service
 * Maximize ad revenue with real-time bidding
 */

interface BidRequest {
  adUnitId: string;
  sizes: Array<[number, number]>;
  userId?: string;
  videoId?: string;
}

interface BidResponse {
  bidder: string;
  cpm: number;
  creative: string;
  width: number;
  height: number;
}

export class HeaderBiddingService {
  private bidders = [
    { name: 'google-ad-manager', endpoint: 'https://securepubads.g.doubleclick.net/gampad/ads' },
    { name: 'amazon-aps', endpoint: 'https://aax.amazon-adsystem.com/e/dtb/bid' },
    { name: 'prebid', endpoint: 'https://prebid.adnxs.com/pbs/v1/openrtb2/auction' },
  ];

  private timeout = 1000; // 1 second max for bids

  /**
   * Run header bidding auction
   */
  async runAuction(request: BidRequest): Promise<BidResponse | null> {
    console.log(`💰 [Header Bidding] Starting auction for ${request.adUnitId}`);
    
    const startTime = Date.now();

    // Request bids from all bidders in parallel
    const bidPromises = this.bidders.map(bidder => 
      this.requestBid(bidder, request)
    );

    // Race against timeout
    const bids = await Promise.race([
      Promise.all(bidPromises),
      this.timeoutPromise()
    ]);

    const elapsedTime = Date.now() - startTime;

    if (!bids || bids.length === 0) {
      console.log(`⚠️ [Header Bidding] No bids received (${elapsedTime}ms)`);
      return null;
    }

    // Select highest CPM bid
    const winningBid = bids.reduce((highest, current) => 
      current.cpm > highest.cpm ? current : highest
    );

    console.log(`✅ [Header Bidding] Winner: ${winningBid.bidder} at $${winningBid.cpm} CPM (${elapsedTime}ms)`);

    return winningBid;
  }

  private async requestBid(bidder: { name: string; endpoint: string }, request: BidRequest): Promise<BidResponse> {
    try {
      const response = await fetch(bidder.endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          adUnitId: request.adUnitId,
          sizes: request.sizes,
          userId: request.userId,
          videoId: request.videoId,
        }),
        signal: AbortSignal.timeout(this.timeout),
      });

      const data = await response.json();

      return {
        bidder: bidder.name,
        cpm: data.cpm || 0,
        creative: data.creative || '',
        width: data.width || 0,
        height: data.height || 0,
      };
    } catch (error) {
      console.warn(`⚠️ [Header Bidding] ${bidder.name} failed:`, error);
      return {
        bidder: bidder.name,
        cpm: 0,
        creative: '',
        width: 0,
        height: 0,
      };
    }
  }

  private timeoutPromise(): Promise<BidResponse[]> {
    return new Promise(resolve => {
      setTimeout(() => resolve([]), this.timeout);
    });
  }

  /**
   * Preload ad creative for instant display
   */
  async preloadCreative(creative: string): Promise<void> {
    const img = new Image();
    img.src = creative;
    await new Promise((resolve, reject) => {
      img.onload = resolve;
      img.onerror = reject;
    });
    console.log('✅ [Header Bidding] Creative preloaded');
  }
}

export const headerBiddingService = new HeaderBiddingService();
export default headerBiddingService;
