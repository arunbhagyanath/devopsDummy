import random

from django.http import HttpResponse
import logging

logger = logging.getLogger()


def index(request):
    try:
        raise AssertionError("Test {}".format(random.randint(1, 100)))
    except Exception as e:
        logger.exception(str(e))
    return HttpResponse('Sent sentry error')
