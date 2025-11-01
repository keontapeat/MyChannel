export type Init = {
    apiBase: string;
    token: string;
};
export type Referral = {
    code: string;
    url: string;
};
export declare class ChannelBoost {
    private static base;
    private static token;
    static init(cfg: Init): void;
    private static req;
    static createReferral(userId: string, source?: string): Promise<Referral>;
    static logInstall(p: {
        platform: string;
        locale: string;
        source?: string;
        campaign?: string;
        referral?: string;
    }): Promise<any>;
    static funnelStep(userId: string, step: 'signup' | 'first_upload' | 'invited_3'): Promise<any>;
    static isReviewEligible(userId: string): Promise<{
        eligible: boolean;
        reason?: string;
    }>;
    static logReview(userId: string, deviceHash: string, outcome: 'shown' | 'rated' | 'skipped' | 'never_ask'): Promise<any>;
    static getAsoMetadata(locale?: string): Promise<any>;
}
export declare class MyChannelSDK {
    private base;
    private token?;
    constructor(apiBase: string, token?: string);
    private req;
    search(q: string, k?: number, videoId?: string): Promise<{
        results: {
            video_id: string;
            t_start: number;
            t_end: number;
            score: number;
            keyframe_url: string;
            text_snippet: string;
        }[];
    }>;
    chapters(videoId: string): Promise<{
        chapters: any[];
    }>;
    tags(videoId: string): Promise<{
        tags: any[];
    }>;
    tip(toUserId: string, amount: number, currency?: string): Promise<unknown>;
}
