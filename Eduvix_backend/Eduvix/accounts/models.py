from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.db import models
from django.utils import timezone

class UserManager(BaseUserManager):
    def create_user(self, email, username, password=None, **extra_fields):
        if not email:
            raise ValueError("Users must have an email")
        email = self.normalize_email(email)
        extra_fields.setdefault("role", "student")
        user = self.model(
            email=email,
            username=username,
            **extra_fields
        )
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_student(self, email, username, password, **extra_fields):
        extra_fields.setdefault("role", "student")
        user = self.create_user(email, username, password, **extra_fields)
        Student.objects.create(user=user)
        return user

    def create_teacher(self, email, username, password, **extra_fields):
        extra_fields.setdefault("role", "teacher")
        user = self.create_user(email, username, password, **extra_fields)
        Teacher.objects.create(user=user)
        return user

    def create_superuser(self, email, username, password, **extra_fields):
        extra_fields.setdefault("role", "admin")
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        return self.create_user(email, username, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    ROLE_CHOICES = (
        ("student", "Student"),
        ("teacher", "Teacher"),
        ("admin", "Admin"),
    )

    email = models.EmailField(unique=True)
    username = models.CharField(max_length=50, unique=True)
    first_name = models.CharField(max_length=50)
    last_name = models.CharField(max_length=50)
    phone = models.CharField(max_length=30)
    avatar = models.TextField(blank=True, null=True)
    bio = models.TextField(blank=True, null=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="student")
    is_active = models.BooleanField(default=True)
    is_verified = models.BooleanField(default=False)
    is_staff = models.BooleanField(default=False)
    last_login = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    REQUIRED_FIELDS = ["email", "first_name", "last_name", "phone"]
    USERNAME_FIELD ="username"

    objects = UserManager()

    def __str__(self):
        return f"{self.username} ({self.role})"


class Teacher(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, primary_key=True)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.0)
    total_earned = models.DecimalField(max_digits=12, decimal_places=2, default=0.0)
    total_commission = models.DecimalField(max_digits=12, decimal_places=2, default=0.0)

    def __str__(self):
        return f"Teacher: {self.user.username}"


class Student(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, primary_key=True)
    points = models.IntegerField(default=0)
    level = models.CharField(max_length=50, blank=True, null=True)

    def __str__(self):
        return f"Student: {self.user.username}"