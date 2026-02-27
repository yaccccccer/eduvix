from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import User,Student

class LoginSerializer(serializers.Serializer):
    email=serializers.EmailField()
    password=serializers.CharField(write_only=True)
    
    def validate(self, data):
        email = data.get("email")
        password = data.get("password")
        user = authenticate(username=email, password=password)
        
        if user:
            data['user'] = user
            return data
        raise serializers.ValidationError("password or email incorect")
    
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