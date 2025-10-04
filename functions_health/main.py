import functions_framework

@functions_framework.http
def health(request):
    return ("OK", 200, {"Content-Type": "text/plain"})
