from django.conf.urls import url

from dumbapp import views

urlpatterns = [
    url(r'^$', views.index),
]
