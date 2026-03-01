from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import User
from .utils import generate_otp,verify_otp,send_otp_email

class LoginSerializer(serializers.Serializer):
    username=serializers.CharField(max_length=50)
    password=serializers.CharField(write_only=True)
    
    def validate(self, data):
        username = data.get("username")
        password = data.get("password")
        user = authenticate(username=username, password=password)
        
        if user:
            data['user'] = user
            return data
        raise serializers.ValidationError("password or username incorect")
    
class StudentRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    class Meta:
        model=User
        fields = ['email', 'username', 'first_name', 'last_name', 'phone', 'password']
        
    def create(self, validated_data):
        user = User.objects.create_student(
            email=validated_data['email'],
            username=validated_data['username'],
            password = validated_data.pop('password'),
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name'],
            phone=validated_data['phone']
        )
        return user
    
class SendOTPSerializer(serializers.Serializer):
    email=serializers.EmailField()
    
    def validate_email(self,value):
        try:
            user = User.objects.get(email=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("No user found with this email.")

        if user.is_verified:
            raise serializers.ValidationError("User is already verified")
        
        return value
    
    def create(self, validated_data):
        email=validated_data['email']
        token,otp=generate_otp(email)
        
        send_otp_email(email,otp)
        
        return token
        
class VerifyOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()
    otp = serializers.CharField(max_length=6)
    token = serializers.CharField()

    def validate(self, data):
        if not verify_otp(data['email'],data['otp'], data['token']):
            raise serializers.ValidationError(
                "The verification code is invalid or has expired."
            )
        return data