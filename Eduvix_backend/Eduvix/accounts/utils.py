import hashlib,random,base64,hmac,time
from Eduvix.settings import SECRET_KEY
from django.core.mail import send_mail


def generate_otp(email):
    otp=f"{random.randint(0, 999999):06}"
    timestamp = int(time.time())
    msg=f"{otp}{timestamp}{email}".encode()
    signature=hmac.new(SECRET_KEY.encode(),msg,hashlib.sha256).hexdigest()
    token=f"{timestamp}:{email}:{signature}"
    return token,otp

def verify_otp(request_email,otp,token,valid_minutes=3):
    try:
        timestamp,email,signature = token.split(":")
        
        timestamp = int(timestamp)
        
        if email != request_email:
            return False

        if time.time() - timestamp > valid_minutes * 60:
            return False
        
        msg=f"{otp}{timestamp}{email}".encode()
        expected_signature=hmac.new(SECRET_KEY.encode(),msg,hashlib.sha256).hexdigest()
        
        return hmac.compare_digest(signature, expected_signature)

    except ValueError:
        return False
        
def send_otp_email(email, otp):
    subject = 'Your Eduvix Verification Code'
    
    plain_message = f"Hello,\nYour verification code for Eduvix is: {otp}\nThis code is valid for 3 minutes. Do not share it with anyone."
    
    message = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Eduvix Verification Code</title>
    <style>
        body {{
        font-family: 'Poppins', sans-serif;
        background-color: #f4f4f8;
        margin: 0;
        padding: 0;
        }}
        .container {{
        width: 100%;
        padding: 30px 0;
        background-color: #f4f4f8;
        }}
        .card {{
        max-width: 600px;
        margin: auto;
        background-color: #ffffff;
        border-radius: 12px;
        box-shadow: 0 8px 30px rgba(0,0,0,0.1);
        padding: 40px;
        text-align: center;
        }}
        .logo {{
        width: 80px;
        margin-bottom: 20px;
        }}
        .title {{
        color: #6c63ff;
        font-size: 26px;
        margin-bottom: 15px;
        }}
        .subtitle {{
        color: #333333;
        font-size: 16px;
        line-height: 1.6;
        margin-bottom: 25px;
        }}
        .otp {{
        display: inline-block;
        padding: 15px 30px;
        font-size: 24px;
        font-weight: bold;
        letter-spacing: 2px;
        color: #ffffff;
        background: linear-gradient(90deg, #7b6cff, #6c63ff);
        border-radius: 8px;
        margin: 20px 0;
        }}
        .footer {{
        color: #888888;
        font-size: 14px;
        margin-top: 25px;
        }}
        @media (max-width: 640px) {{
        .card {{
            padding: 30px 20px;
        }}
        .otp {{
            padding: 12px 20px;
            font-size: 20px;
        }}
        }}
    </style>
    </head>
    <body>
    <div class="container">
        <div class="card">
        <!-- Logo (optional) -->
        <img src="https://yourdomain.com/static/logo.png" alt="Eduvix Logo" class="logo">

        <div class="title">Eduvix Verification Code</div>

        <div class="subtitle">
            Hello,<br>
            Your verification code for <strong>Eduvix</strong> is:
        </div>

        <div class="otp">{otp}</div>

        <div class="subtitle">
            This code is valid for <strong>3 minutes</strong>. Please do not share it with anyone.<br><br>
            If you did not request this code, please ignore this email.
        </div>

        <div class="footer">
            Best regards,<br>
            <strong>The Eduvix Team</strong>
        </div>
        </div>
    </div>
    </body>
    </html>
    """
                
    from_email = '510lgbtg4n422@gmail.com'
    recipient_list = [email]

    send_mail(
        subject=subject,
        html_message=message,
        message=plain_message,
        from_email=from_email,
        recipient_list=recipient_list,
        fail_silently=False,
    )