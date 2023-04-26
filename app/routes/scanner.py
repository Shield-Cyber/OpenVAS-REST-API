from fastapi import APIRouter, Depends, Response
from app.utils.auth import Auth, PASSWORD
from gvm.protocols.gmp import Gmp
import logging
from gvm.connections import UnixSocketConnection
from typing import Annotated, Optional
from app import LOGGING_PREFIX

ENDPOINT = "scanner"

LOGGER = logging.getLogger(f"{LOGGING_PREFIX}.{ENDPOINT}")

ROUTER = APIRouter(
    prefix=f"/{ENDPOINT}",
    tags=[ENDPOINT]
    )

### ROUTES ###

@ROUTER.get("/get/scanners")
async def get_scanners(
    current_user: Annotated[Auth.User, Depends(Auth.get_current_active_user)],
    filter_string: Optional[str] = None,
    filter_id: Optional[str] = None,
    trash: Optional[bool] = None,
    details: Optional[bool] = None,
    ):
    """Request a list of scanners

        Arguments:

            filter_string: Filter term to use for the query
            filter_id: UUID of an existing filter to use for the query
            trash: Whether to get the trashcan scanners instead
            details:  Whether to include extra details like tasks using this scanner

        Returns:
            The response.
        """
    with Gmp(connection=UnixSocketConnection()) as gmp:
        gmp.authenticate(username=current_user.username, password=PASSWORD)
        return Response(content=gmp.get_scanners(filter_string=filter_string,filter_id=filter_id,trash=trash,details=details), media_type="application/xml")