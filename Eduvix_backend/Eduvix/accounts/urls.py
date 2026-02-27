from django.urls import path
from .views import LoginView,StudentRegistrationView

urlpatterns = [
    path('login/', LoginView.as_view(), name='login'),
    path('register/',StudentRegistrationView.as_view(),name='register')
]