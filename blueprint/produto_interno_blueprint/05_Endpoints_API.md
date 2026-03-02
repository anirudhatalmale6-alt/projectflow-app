
# Endpoints API

Auth:
GET /auth/google
POST /auth/callback
GET /me

Projects:
POST /projects
GET /projects
POST /projects/:id/jobs

Assets:
POST /assets
POST /assets/:id/versions
POST /versions/:id/approve

Reviews:
POST /jobs/:id/reviews
POST /reviews/:id/comments

Chat:
GET /channels/:id/messages

Calendar:
POST /projects/:id/calendar/events
PATCH /calendar/events/:id
