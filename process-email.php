<?php
if ($_POST) {
    $to = "leads@mychannel.live"; // Your Namecheap email
    $subject = "New MyChannel Early Access Signup";
    $email = filter_var($_POST['email'], FILTER_SANITIZE_EMAIL);
    
    // Validate email
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        header("Location: https://www.mychannel.live/error.html");
        exit();
    }
    
    // Email content
    $message = "New early access signup:\n\n";
    $message .= "Email: " . $email . "\n";
    $message .= "Time: " . date('Y-m-d H:i:s') . "\n";
    $message .= "IP Address: " . $_SERVER['REMOTE_ADDR'] . "\n";
    
    // Headers
    $headers = "From: noreply@mychannel.live\r\n";
    $headers .= "Reply-To: " . $email . "\r\n";
    $headers .= "X-Mailer: PHP/" . phpversion();
    
    // Send email
    if (mail($to, $subject, $message, $headers)) {
        // Save to CSV file as backup
        $csv_line = date('Y-m-d H:i:s') . ',' . $email . ',' . $_SERVER['REMOTE_ADDR'] . "\n";
        file_put_contents('email-signups.csv', $csv_line, FILE_APPEND);
        
        header("Location: https://www.mychannel.live/thank-you.html");
    } else {
        header("Location: https://www.mychannel.live/error.html");
    }
} else {
    header("Location: https://www.mychannel.live/");
}
?>