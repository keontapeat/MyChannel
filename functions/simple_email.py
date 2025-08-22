from firebase_functions import firestore_fn, options
from firebase_admin import firestore, initialize_app
import logging

# Initialize Firebase Admin
initialize_app()

@firestore_fn.on_document_created(document="users/{userId}")
def send_welcome_email(event: firestore_fn.Event[firestore_fn.DocumentSnapshot]) -> None:
    """Send welcome email when user is created"""
    try:
        # Get user data
        user_data = event.data.to_dict()
        email = user_data.get('email')
        username = user_data.get('displayName', 'Creator')
        user_id = event.params['userId']
        
        if not email:
            logging.error("No email found for user")
            return
        
        # Log the welcome email (you'd integrate with email service)
        logging.info(f"🎬 Welcome email for {username} ({email})")
        logging.info(f"Beautiful MyChannel email would be sent here!")
        
        # Update user document
        firestore.client().collection('users').document(user_id).update({
            'welcome_email_sent': True,
            'welcome_email_sent_at': firestore.SERVER_TIMESTAMP
        })
        
        print(f"✅ Welcome email processed for {username}")
        
    except Exception as e:
        logging.error(f"❌ Error: {str(e)}")
