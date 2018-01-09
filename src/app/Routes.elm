module Routes exposing (..)

import Http
import Navigation exposing (Location)
import RemoteData exposing (WebData)
import Slug exposing (Slug)
import UrlParser exposing (..)


type Route
    = HomeRoute
    | SignUpRoute
    | LoginRoute
    | DraftRoute String
    | DraftsRoute
    | PublicDraftsRoute
    | DashboardRoute


type RouteError
    = NotFound
    | NotAllowed Route Route


parseLocation : Location -> Result RouteError Route
parseLocation location =
    case parseHash matchers location of
        Just route ->
            Ok route

        Nothing ->
            Err NotFound


matchers : Parser (Route -> a) a
matchers =
    oneOf
        [ map HomeRoute top
        , map SignUpRoute (s "signup")
        , map LoginRoute (s "login")
        , map DraftRoute (s "editor" </> string)
        , map DashboardRoute (s "dashboard")
        , map DraftsRoute (s "drafts")
        , map PublicDraftsRoute (s "drafts" </> s "public")
        ]


slugMatcher : Parser (Slug -> a) a
slugMatcher =
    custom "TOPIC_TITLE" <|
        \segment ->
            case Slug.generate segment of
                Just slug ->
                    Ok slug

                Nothing ->
                    Err "Malformed Path"


path : Route -> String
path route =
    case route of
        HomeRoute ->
            "#"

        SignUpRoute ->
            "#signup"

        LoginRoute ->
            "#login"

        DraftRoute id ->
            "#editor/" ++ id

        DashboardRoute ->
            "#dashboard"

        DraftsRoute ->
            "#drafts"

        PublicDraftsRoute ->
            "#drafts/public"



