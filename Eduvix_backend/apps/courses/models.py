from django.db import models
from django.db.models import CheckConstraint,Q
from django.contrib.auth import get_user_model
from categories.models import Category
from common.mixins import SoftDeleteMixin

User = get_user_model()

class Course(SoftDeleteMixin,models.Model):
    teacher=models.ForeignKey(User, on_delete=models.CASCADE, related_name="courses")
    category=models.ForeignKey(Category,on_delete=models.RESTRICT,related_name="courses")
    title=models.CharField(max_length=255,null=False) 
    description=models.TextField()
    photo=models.TextField()
    price=models.DecimalField(max_digits=12,decimal_places=2,null=False,default=0.00)
    is_published=models.BooleanField(default=False)
    rating=models.DecimalField(max_digits=3,decimal_places=2,default=0.00)
    total_reviews=models.IntegerField(default=0)
    created_at=models.DateTimeField(auto_now_add=True) 
    updated_at=models.DateTimeField(auto_now=True) 
    
    class Meta:
        constraints = [
            CheckConstraint(check=Q(price__gte=0), name='price_non_negative')
        ]