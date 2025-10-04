// Firebase Functions for MyChannel Email System
// This file shows how to set up custom email templates with Firebase Functions

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure your email service (Gmail, SendGrid, etc.)
const transporter = nodemailer.createTransporter({
    service: 'gmail',
    auth: {
        user: 'noreply@mychannel.live',
        pass: 'your-app-password' // Use app-specific password
    }
});

// Welcome Email Template
const getWelcomeEmailHTML = (username, verificationLink) => `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to MyChannel!</title>
</head>
<body style="margin: 0; padding: 0; background: #0A0A0A; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif;">
    
    <div style="max-width: 600px; margin: 0 auto; background: linear-gradient(135deg, #0A0A0A 0%, #1a1a1a 100%); color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 20px 40px rgba(0,0,0,0.3);">
        
        <!-- Header -->
        <div style="background: linear-gradient(135deg, #FF4444 0%, #FF6B6B 100%); padding: 40px 30px; text-align: center; position: relative;">
            <div style="background: rgba(255,255,255,0.1); width: 80px; height: 80px; border-radius: 50%; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center; font-size: 40px; box-shadow: 0 8px 24px rgba(0,0,0,0.2);">
                🎬
            </div>
            <h1 style="margin: 0; font-size: 32px; font-weight: bold; text-shadow: 0 2px 4px rgba(0,0,0,0.3);">
                Welcome to MyChannel!
            </h1>
            <p style="margin: 10px 0 0; font-size: 18px; opacity: 0.9;">
                The Future of Video Streaming is Here
            </p>
        </div>
        
        <!-- Main Content -->
        <div style="padding: 40px 30px;">
            <div style="text-align: center; margin-bottom: 30px;">
                <h2 style="margin: 0 0 15px; font-size: 24px; color: #FF4444;">
                    Hey ${username}! 🔥
                </h2>
                <p style="font-size: 16px; line-height: 1.6; color: #cccccc; margin: 0;">
                    You just joined something <strong style="color: #00FFE1;">REVOLUTIONARY</strong>! 
                    MyChannel isn't just another video platform - we're building the future where creators get paid what they deserve.
                </p>
            </div>
            
            <!-- Benefits Grid -->
            <div style="background: rgba(255, 68, 68, 0.1); border: 1px solid rgba(255, 68, 68, 0.3); border-radius: 12px; padding: 25px; margin: 30px 0;">
                <h3 style="margin: 0 0 20px; color: #FF4444; font-size: 20px; text-align: center;">
                    🎯 What Makes MyChannel Different?
                </h3>
                
                <table style="width: 100%; border-collapse: collapse;">
                    <tr>
                        <td style="padding: 15px; background: rgba(0, 255, 225, 0.1); border-radius: 8px; text-align: center; width: 50%;">
                            <div style="font-size: 24px; margin-bottom: 8px;">💰</div>
                            <strong style="color: #00FFE1; display: block;">90% Revenue Share</strong>
                            <p style="margin: 5px 0 0; font-size: 14px; color: #aaa;">Keep what you earn - we only take 10%</p>
                        </td>
                        <td style="width: 10px;"></td>
                        <td style="padding: 15px; background: rgba(0, 255, 225, 0.1); border-radius: 8px; text-align: center; width: 50%;">
                            <div style="font-size: 24px; margin-bottom: 8px;">🚀</div>
                            <strong style="color: #00FFE1; display: block;">Zero Upload Limits</strong>
                            <p style="margin: 5px 0 0; font-size: 14px; color: #aaa;">Upload as much as you want, anytime</p>
                        </td>
                    </tr>
                    <tr><td colspan="3" style="height: 15px;"></td></tr>
                    <tr>
                        <td style="padding: 15px; background: rgba(0, 255, 225, 0.1); border-radius: 8px; text-align: center;">
                            <div style="font-size: 24px; margin-bottom: 8px;">⚡</div>
                            <strong style="color: #00FFE1; display: block;">Lightning Fast</strong>
                            <p style="margin: 5px 0 0; font-size: 14px; color: #aaa;">Built on Google Cloud for speed</p>
                        </td>
                        <td style="width: 10px;"></td>
                        <td style="padding: 15px; background: rgba(0, 255, 225, 0.1); border-radius: 8px; text-align: center;">
                            <div style="font-size: 24px; margin-bottom: 8px;">🎨</div>
                            <strong style="color: #00FFE1; display: block;">Creator Tools</strong>
                            <p style="margin: 5px 0 0; font-size: 14px; color: #aaa;">Analytics, editing, and monetization</p>
                        </td>
                    </tr>
                </table>
            </div>
            
            <!-- Verification Button -->
            <div style="text-align: center; margin: 40px 0;">
                <div style="background: linear-gradient(135deg, #FF4444 0%, #FF6B6B 100%); padding: 2px; border-radius: 12px; display: inline-block; box-shadow: 0 8px 24px rgba(255, 68, 68, 0.3);">
                    <a href="${verificationLink}" style="display: inline-block; background: linear-gradient(135deg, #FF4444 0%, #FF6B6B 100%); color: white; text-decoration: none; padding: 16px 40px; border-radius: 10px; font-weight: bold; font-size: 18px;">
                        🚀 Verify Your Account & Get Started
                    </a>
                </div>
                <p style="margin: 15px 0 0; font-size: 14px; color: #888;">
                    This link expires in 24 hours for security
                </p>
            </div>
            
            <!-- What's Next -->
            <div style="background: rgba(0, 255, 225, 0.05); border-radius: 12px; padding: 25px; margin: 30px 0; border: 1px solid rgba(0, 255, 225, 0.2);">
                <h3 style="margin: 0 0 20px; color: #00FFE1; text-align: center;">
                    🎬 What's Next?
                </h3>
                
                <table style="width: 100%;">
                    <tr>
                        <td style="width: 40px; vertical-align: top;">
                            <div style="background: #FF4444; color: white; width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; text-align: center; line-height: 24px;">1</div>
                        </td>
                        <td style="color: #ccc; vertical-align: top; padding-bottom: 15px;">Verify your email (click the button above)</td>
                    </tr>
                    <tr>
                        <td style="width: 40px; vertical-align: top;">
                            <div style="background: #FF4444; color: white; width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; text-align: center; line-height: 24px;">2</div>
                        </td>
                        <td style="color: #ccc; vertical-align: top; padding-bottom: 15px;">Complete your creator profile</td>
                    </tr>
                    <tr>
                        <td style="width: 40px; vertical-align: top;">
                            <div style="background: #FF4444; color: white; width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; text-align: center; line-height: 24px;">3</div>
                        </td>
                        <td style="color: #ccc; vertical-align: top;">Upload your first video and start earning!</td>
                    </tr>
                </table>
            </div>
            
            <!-- Testimonial -->
            <div style="background: linear-gradient(135deg, rgba(255, 68, 68, 0.1) 0%, rgba(0, 255, 225, 0.1) 100%); border-radius: 12px; padding: 25px; margin: 30px 0; text-align: center; border: 1px solid rgba(255, 68, 68, 0.2);">
                <div style="font-size: 40px; margin-bottom: 15px;">💬</div>
                <p style="font-style: italic; font-size: 16px; color: #ddd; margin: 0 0 15px; line-height: 1.6;">
                    "MyChannel changed my life! I'm making 3x more than my old platform and the community is incredible. This is the future!"
                </p>
                <div style="color: #FF4444; font-weight: bold;">- Sarah M., Creator since Day 1</div>
            </div>
        </div>
        
        <!-- Footer -->
        <div style="background: rgba(0,0,0,0.3); padding: 30px; text-align: center; border-top: 1px solid rgba(255, 68, 68, 0.2);">
            <div style="margin-bottom: 15px;">
                <span style="color: #FF4444; font-weight: bold; font-size: 18px;">🎬 MyChannel</span>
            </div>
            
            <p style="font-size: 14px; color: #888; margin: 0 0 15px; line-height: 1.5;">
                The future of video streaming where creators thrive.<br>
                Built with ❤️ for the creator economy.
            </p>
            
            <div style="font-size: 12px; color: #666;">
                <p style="margin: 15px 0 0;">
                    © 2024 MyChannel. All rights reserved.<br>
                    You're receiving this because you signed up for MyChannel.
                </p>
            </div>
        </div>
    </div>
    
</body>
</html>
`;

// Send Welcome Email Function
exports.sendWelcomeEmail = functions.auth.user().onCreate(async (user) => {
    const email = user.email;
    const displayName = user.displayName || 'Creator';
    
    // Generate custom verification link
    const actionCodeSettings = {
        url: 'https://mychannel.live', // Your custom domain
        handleCodeInApp: true
    };
    
    try {
        const verificationLink = await admin.auth().generateEmailVerificationLink(email, actionCodeSettings);
        
        const mailOptions = {
            from: 'MyChannel <noreply@mychannel.live>',
            to: email,
            subject: '🎬 Welcome to MyChannel - Verify Your Account!',
            html: getWelcomeEmailHTML(displayName, verificationLink)
        };
        
        await transporter.sendMail(mailOptions);
        console.log('✅ Welcome email sent to:', email);
        
        // Track email sent in analytics
        await admin.firestore().collection('analytics').add({
            type: 'email_sent',
            event: 'welcome_email',
            userId: user.uid,
            email: email,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        
    } catch (error) {
        console.error('❌ Error sending welcome email:', error);
    }
});

// Email Verification Success Function
exports.onEmailVerified = functions.firestore
    .document('users/{userId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        
        // Check if email was just verified
        if (!before.emailVerified && after.emailVerified) {
            const userId = context.params.userId;
            const user = await admin.auth().getUser(userId);
            
            const successEmailHTML = `
            <!DOCTYPE html>
            <html>
            <body style="font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif; background: #0A0A0A; color: white; margin: 0; padding: 20px;">
                <div style="max-width: 600px; margin: 0 auto; background: linear-gradient(135deg, #0A0A0A 0%, #1a1a1a 100%); border-radius: 16px; overflow: hidden;">
                    
                    <div style="background: linear-gradient(135deg, #00FFE1 0%, #00D4AA 100%); padding: 40px; text-align: center;">
                        <div style="font-size: 60px; margin-bottom: 20px;">🎉</div>
                        <h1 style="margin: 0; color: #0A0A0A; font-size: 28px;">Welcome to the Future, ${after.displayName}!</h1>
                        <p style="margin: 10px 0 0; color: #0A0A0A; opacity: 0.8;">Your account is verified and ready to rock! 🚀</p>
                    </div>
                    
                    <div style="padding: 40px; text-align: center;">
                        <h2 style="color: #00FFE1; margin: 0 0 20px;">🔥 You're officially part of the revolution!</h2>
                        
                        <p style="color: #ccc; margin: 0 0 30px; line-height: 1.6;">
                            Your MyChannel creator account is now <strong style="color: #00FFE1;">ACTIVE</strong>! 
                            Time to start building your empire and earning that 90% revenue share.
                        </p>
                        
                        <div style="background: rgba(0, 255, 225, 0.1); border-radius: 12px; padding: 25px; margin: 30px 0;">
                            <h3 style="color: #00FFE1; margin: 0 0 20px;">📊 Your Creator Dashboard</h3>
                            <p style="color: #aaa; margin: 0;">Ready to upload your first video and start earning! 🎬</p>
                        </div>
                        
                        <div style="margin: 30px 0;">
                            <a href="https://mychannel.live" style="background: linear-gradient(135deg, #FF4444 0%, #FF6B6B 100%); color: white; text-decoration: none; padding: 16px 32px; border-radius: 8px; font-weight: bold; display: inline-block;">
                                🎬 Start Creating Now
                            </a>
                        </div>
                    </div>
                </div>
            </body>
            </html>
            `;
            
            const mailOptions = {
                from: 'MyChannel <noreply@mychannel.live>',
                to: user.email,
                subject: '🎉 Account Verified - Welcome to MyChannel!',
                html: successEmailHTML
            };
            
            await transporter.sendMail(mailOptions);
            console.log('✅ Success email sent to:', user.email);
        }
    });

// Newsletter Function
exports.sendNewsletter = functions.https.onCall(async (data, context) => {
    // Verify admin access
    if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    
    const { subject, content, userSegment } = data;
    
    try {
        // Get user emails based on segment
        let usersQuery = admin.firestore().collection('users');
        
        if (userSegment === 'verified') {
            usersQuery = usersQuery.where('emailVerified', '==', true);
        } else if (userSegment === 'creators') {
            usersQuery = usersQuery.where('videoCount', '>', 0);
        }
        
        const usersSnapshot = await usersQuery.get();
        const emails = [];
        
        usersSnapshot.forEach(doc => {
            const user = doc.data();
            if (user.email) {
                emails.push(user.email);
            }
        });
        
        // Send batch emails
        const emailPromises = emails.map(email => {
            const mailOptions = {
                from: 'MyChannel <noreply@mychannel.live>',
                to: email,
                subject: subject,
                html: content
            };
            return transporter.sendMail(mailOptions);
        });
        
        await Promise.all(emailPromises);
        
        return { success: true, sent: emails.length };
    } catch (error) {
        console.error('Newsletter send error:', error);
        throw new functions.https.HttpsError('internal', 'Failed to send newsletter');
    }
});
