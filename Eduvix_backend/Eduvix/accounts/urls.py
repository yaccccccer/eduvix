from django.urls import path
from .views import LoginView,StudentRegistrationView,LogoutView,SendOTPView,VerifyOTPView,RefreshTokenView

urlpatterns = [
    path('login/', LoginView.as_view(), name='login'),
    path('register/',StudentRegistrationView.as_view(),name='register'),
    path('logout/',LogoutView.as_view(),name='logout'),
    path('otp/send/', SendOTPView.as_view(), name='otp-send'),
    path('otp/verify/', VerifyOTPView.as_view(), name='otp-verify'),
    path('token/refresh/', RefreshTokenView.as_view(), name='refresh-token')
]