from .auth import *
from fastapi import FastAPI, Depends, HTTPException, status, Response
from typing import Annotated, Optional, Union
from gvm.protocols.gmpv208.entities.report_formats import ReportFormatType
from gvm.connections import UnixSocketConnection
from gvm.protocols.gmp import Gmp
import logging
import time
import os

# Logging
logger = logging.getLogger("uvicorn")

# Socket Path
path = '/run/gvmd/gvmd.sock'

# Socket Connection
CONNECTION = None

# Description
DESCRIPTION = """This is a translation API that calls the XML API calls on the local
Greenbone Vulnerability Scanner and converts them to REST API calls for easier use by most systems."""

# Main App / API
app = FastAPI(
    title="Greenbone Rest API",
    description=DESCRIPTION,
    version=os.getenv("VERSION"),
    swagger_ui_parameters={"tagsSorter": "alpha", "operationsSorter": "alpha"}
)

# Pre Startup Connection to gvmd Socket
@app.on_event("startup")
async def startup():
    while True:
        try:
            global CONNECTION
            CONNECTION = UnixSocketConnection(path=path)
            with Gmp(connection=CONNECTION) as gmp:
                logger.info(gmp.get_version())
                break
        except:
            logger.warning("waiting 1 second for gvmd socket")
            time.sleep(1)

### AUTH DATA ###

@app.post("/authenticate", response_model=Token, tags=["auth"])
async def authenticate(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()]
):
    user = authenticate_user(users_db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/describe_auth", tags=["auth"])
async def describe_auth(
    current_user: Annotated[User, Depends(get_current_active_user)]
):
    """Describe authentication methods

        Returns a list of all used authentication methods if such a list is available.

        Returns:
            The response.
        """
    with Gmp(connection=CONNECTION) as gmp:
        if verify_password(PASSWORD, current_user.hashed_password):
            gmp.authenticate(username=current_user.username, password=PASSWORD)
        return Response(content=gmp.describe_auth(), media_type="application/xml")

### VERSION DATA ###

@app.get("/get/version", tags=["version"])
async def get_version(
    current_user: Annotated[User, Depends(get_current_active_user)]
):
    """Get the Greenbone Vulnerability Manager Protocol version used by the remote gvmd.

        Returns:
            The response.
        """
    with Gmp(connection=CONNECTION) as gmp:
        return Response(content=gmp.get_version(), media_type="application/xml")

### TASK DATA ###

@app.get("/get/tasks", tags=["task"])
async def get_tasks(
    current_user: Annotated[User, Depends(get_current_active_user)],
    filter_string: Optional[str] = None,
    filter_id: Optional[str] = None,
    trash: Optional[bool] = None,
    details: Optional[bool] = None,
    schedules_only: Optional[bool] = None
):
    """Request a list of tasks

        Arguments:
        
            filter_string: Filter term to use for the query
            filter_id: UUID of an existing filter to use for the query
            trash: Whether to get the trashcan tasks instead
            details: Whether to include full task details
            schedules_only: Whether to only include id, name and schedule details

        Returns:
            The response.
        """
    with Gmp(connection=CONNECTION) as gmp:
        if verify_password(PASSWORD, current_user.hashed_password):
            gmp.authenticate(username=current_user.username, password=PASSWORD)
        return Response(content=gmp.get_tasks(filter_string=filter_string, filter_id=filter_id, trash=trash, details=details, schedules_only=schedules_only), media_type="application/xml")

@app.get("/get/task", tags=["task"])
async def get_task(
    current_user: Annotated[User, Depends(get_current_active_user)],
    task_id: str
    ):
    """Request a single task

        Arguments:

            task_id: UUID of an existing task

        Returns:
            The response.
        """
    with Gmp(connection=CONNECTION) as gmp:
        if verify_password(PASSWORD, current_user.hashed_password):
            gmp.authenticate(username=current_user.username, password=PASSWORD)
        return Response(content=gmp.get_task(task_id), media_type="application/xml")

### REPORT DATA ###

@app.get("/get/report", tags=["report"])
async def get_report(
    current_user: Annotated[User, Depends(get_current_active_user)],
    report_id: str,
    filter_string: Optional[str] = None,
    filter_id: Optional[str] = None,
    delta_report_id: Optional[str] = None,
    report_format_id: Optional[Union[str, ReportFormatType]] = None,
    ignore_pagination: Optional[bool] = None,
    details: Optional[bool] = True
):
    """Request a single report

        Arguments:

            report_id: UUID of an existing report
            filter_string: Filter term to use to filter results in the report
            filter_id: UUID of filter to use to filter results in the report
            delta_report_id: UUID of an existing report to compare report to.
            report_format_id: UUID of report format to use or ReportFormatType (enum)
            ignore_pagination: Whether to ignore the filter terms "first" and "rows".
            details: Request additional report information details defaults to True

        Returns:
            The response.
        """
    with Gmp(connection=CONNECTION) as gmp:
        if verify_password(PASSWORD, current_user.hashed_password):
            gmp.authenticate(username=current_user.username, password=PASSWORD)
        return Response(content=gmp.get_report(report_id=report_id, filter_string=filter_string, filter_id=filter_id, delta_report_id=delta_report_id, report_format_id=report_format_id, ignore_pagination=ignore_pagination, details=details), media_type="application/xml")    

### USER DATA ###

@app.get("/get/user", tags=["user"])
async def get_user(
    current_user: Annotated[User, Depends(get_current_active_user)],
    user_id: str
    ):
    """Request a single user

        Arguments:

            user_id: UUID of an existing user

        Returns:
            The response.
        """
    with Gmp(connection=CONNECTION) as gmp:
        if verify_password(PASSWORD, current_user.hashed_password):
            gmp.authenticate(username=current_user.username, password=PASSWORD)
        return Response(content=gmp.get_user(user_id=user_id), media_type="application/xml")

@app.get("/get/user/settings", tags=["user"])
async def get_user_settings(
    current_user: Annotated[User, Depends(get_current_active_user)],
    filter_string: Optional[str] = None
    ):
    """Request a list of user settings

        Arguments:

            filter_string: Filter term to use for the query

        Returns:
            The response.
        """
    with Gmp(connection=CONNECTION) as gmp:
        if verify_password(PASSWORD, current_user.hashed_password):
            gmp.authenticate(username=current_user.username, password=PASSWORD)
        return Response(content=gmp.get_user_settings(filter_string=filter_string), media_type="application/xml")

@app.get("/get/user/setting", tags=["user"])
async def get_user_setting(
    current_user: Annotated[User, Depends(get_current_active_user)],
    setting_id: str
    ):
    """Request a list of user settings

        Arguments:

            filter_string: Filter term to use for the query

        Returns:
            The response.
        """
    with Gmp(connection=CONNECTION) as gmp:
        if verify_password(PASSWORD, current_user.hashed_password):
            gmp.authenticate(username=current_user.username, password=PASSWORD)
        return Response(content=gmp.get_user_setting(setting_id=setting_id), media_type="application/xml")
    
@app.get("/get/users", tags=["user"])
async def get_users(
    current_user: Annotated[User, Depends(get_current_active_user)],
    filter_string: Optional[str] = None,
    filter_id: Optional[str] = None,
    ):
    """Request a list of users

        Arguments:

            filter_string: Filter term to use for the query
            filter_id: UUID of an existing filter to use for the query

        Returns:
            The response.
        """
    with Gmp(connection=CONNECTION) as gmp:
        if verify_password(PASSWORD, current_user.hashed_password):
            gmp.authenticate(username=current_user.username, password=PASSWORD)
        return Response(content=gmp.get_users(filter_id=filter_id, filter_string=filter_string), media_type="application/xml")
    
