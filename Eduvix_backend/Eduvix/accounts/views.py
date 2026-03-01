from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .serializers import LoginSerializer,StudentRegistrationSerializer,SendOTPSerializer,VerifyOTPSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from .models import User
from rest_framework.throttling import AnonRateThrottle
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.exceptions import TokenError, InvalidToken

class SendOTPThrottle(AnonRateThrottle):
    scope = 'Send_otp'
    
class VerifyOTPThrottle(AnonRateThrottle):
    scope = 'Verify_otp'


class LoginView(APIView):
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']

        refresh = RefreshToken.for_user(user)
        
        response = Response({
            "user": {
                "email": user.email,
                "username": user.username,
                "role": user.role,
                "is_verified":user.is_verified,
            }
        }, status=status.HTTP_200_OK)
        
        response.set_cookie(
            key="access_token",
            value=str(refresh.access_token),
            httponly=True,
            secure=False,
            samesite="Lax",
            max_age=3600
        )
        
        response.set_cookie(
            key="refresh_token",
            value=str(refresh),
            httponly=True,
            secure=False,
            samesite="Lax",
            max_age=3600
        )
        
        return response
    
        
        
class StudentRegistrationView(APIView):
    def post(self, request):
        serializer = StudentRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            
            refresh = RefreshToken.for_user(user)
            
            response= Response({
                "message": "Student registered successfully",
                "user": {
                    "email": user.email,
                    "username": user.username,
                    "role": user.role,
                    "is_verified":user.is_verified
                }
            }, status=status.HTTP_201_CREATED)
            
            response.set_cookie(
                key="access_token",
                value=str(refresh.access_token),
                httponly=True,
                secure=False,
                samesite="Lax",
                max_age=3600
            )
            
            response.set_cookie(
                key="refresh_token",
                value=str(refresh),
                httponly=True,
                secure=False,
                samesite="Lax",
                max_age=3600
            )
            
            return response
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class LogoutView(APIView):
    def post(self,request):
        response=Response(
            {"message":"Logged out successfully"},
            status=status.HTTP_200_OK)
        
        response.delete_cookie("access_token")
        response.delete_cookie("refresh_token")
        
        return response

class SendOTPView(APIView):
    
    permission_classes=[IsAuthenticated]
    throttle_classes = [SendOTPThrottle]
    
    def post(self,request):
        serializer= SendOTPSerializer(data=request.data)
        if serializer.is_valid():
            token=serializer.save()
            
            return Response(
                {'message': 'Verification code has been sent successfully.', 'token': token},
                status=status.HTTP_200_OK)
            
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
class VerifyOTPView(APIView):
    
    permission_classes=[IsAuthenticated]
    throttle_classes = [VerifyOTPThrottle]
    
    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)

        if serializer.is_valid():
            email = serializer.validated_data['email']
            
            try:
                user = User.objects.get(email=email)
            except User.DoesNotExist:
                return Response(
                    {"error": "User not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            user.is_verified = True
            user.save()

            return Response({
                'message': 'Verification successful',
                "user": {
                    "email": user.email,
                    "username": user.username,
                    "role": user.role,
                    "is_verified":user.is_verified
                }
            }, status=status.HTTP_200_OK)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
class RefreshTokenView(APIView):
    def post(self,request):
        refresh_token=request.cookies.get("refresh_token")
        
        if not refresh_token:
            return Response(
                {"detail": "Refresh token not found"},
                status=status.HTTP_401_UNAUTHORIZED
            )
            
        try:
            refresh=RefreshToken(refresh_token)
            access=refresh.access_token
            
            response = Response(
                {"detail": "Access token refreshed successfully"},
                status=status.HTTP_200_OK
            )
            
            response.set_cookie(
                key="access_token",
                value=str(access),
                httponly=True,
                secure=False,
                samesite="Lax",
                max_age=3600
            )
            
            return response
            
        except (TokenError, InvalidToken):
            return Response(
                {"detail": "Invalid or expired refresh token"},
                status=status.HTTP_401_UNAUTHORIZED
            )