from flask import Blueprint, render_template, redirect
from user_management import check_logged_in
from enable_disable_functions import *
from device_info import *
from application_info import *
from systemctl_info import *
import subprocess
import os


mynode_pwallet = Blueprint('mynode_pwallet',__name__)


### Page functions (have prefix /app/<app name/)
@mynode_pwallet.route("/info")
def pwallet_page():
    check_logged_in()

    app = get_application("pwallet")
    app_status = get_application_status("pwallet")
    app_status_color = get_application_status_color("pwallet")

    # Load page
    templateData = {
        "title": "myNode - " + app["name"],
        "ui_settings": read_ui_settings(),
        "app_status": app_status,
        "app_status_color": app_status_color,
        "app": app
    }
    return render_template('/app/generic_app.html', **templateData)

