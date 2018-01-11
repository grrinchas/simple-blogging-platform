port module Main exposing (..)

import Api
import Commands exposing (removeTokens, reroute, saveTokens, updateTime)
import Dict
import Err exposing (..)
import Mouse
import Platform.Cmd exposing (batch)
import Ports
import Models exposing (..)
import Navigation exposing (Location)
import Pages
import RemoteData exposing (RemoteData(Failure, Loading, NotAsked, Success), WebData, succeed)
import Routes exposing (..)
import Task
import Time exposing (Time)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.getTokens WhenTokensLoaded
        , Mouse.clicks ClickMouse
        , Time.every (5 * Time.minute) <| autoSaveDraft model
        ]


autoSaveDraft : Model -> Time -> Msg
autoSaveDraft model time =
    case model.route of
        Ok (DraftRoute id) ->
            case RemoteData.map (\user -> Dict.get id user.drafts) model.remote.user |> RemoteData.withDefault Nothing of
                Just draft ->
                    case model.remote.savedDraft of
                        NotAsked ->
                            ClickUpdateDraft draft

                        _ ->
                            case RemoteData.map (\saved -> saved.content /= draft.content || saved.title /= draft.title) model.remote.savedDraft |> RemoteData.withDefault False of
                                True ->
                                    ClickUpdateDraft draft

                                False ->
                                    WhenNoOperation

                Nothing ->
                    WhenNoOperation

        _ ->
            WhenNoOperation


main : Program (Maybe Tokens) Model Msg
main =
    Navigation.programWithFlags WhenLocationChanges
        { init = init
        , view = Pages.view
        , update = update
        , subscriptions = subscriptions
        }


init : Maybe Tokens -> Location -> ( Model, Cmd Msg )
init tokens loc =
    location loc initialModel
        |> updateTokens tokens
        |> withCommands
            [ updateTime ]
        |> andAlso Api.fetchUser
        |> andAlso Api.fetchPublicDrafts


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        WhenNoOperation ->
            ( model, Cmd.none )

        WhenTimeChanges time ->
            ( { model | now = time }, Cmd.none )

        WhenLocationChanges loc ->
            location loc model
                |> resetMenu
                |> reroute

        WhenFormChanges f ->
            form f model
                |> withNoCommand

        WhenMenuChanges m ->
            menu m model
                |> withNoCommand

        WhenTokensLoaded tokens ->
            updateTokens tokens model
                |> withNoCommand

        WhenDraftChanges draft ->
            updateDraft (succeed draft) model
                |> withNoCommand

        ClickUpdateRoute route ->
            ( model, Navigation.newUrl <| path route )

        ClickCreateAccount maybeValid ->
            remoteAccount Loading model
                |> Api.createAccount maybeValid

        ClickLogin maybeValid ->
            remoteUser Loading model
                |> Api.login maybeValid

        ClickLogout ->
            resetRemote model
                |> withCommands
                    [ removeTokens
                    , Navigation.modifyUrl <| path HomeRoute
                    ]

        ClickMouse _ ->
            resetMenu model
                |> withNoCommand

        ClickCreateDraft draft ->
            Api.createDraft draft model

        ClickUpdateDraft draft ->
            remoteUpdatedDraft Loading model
                |> Api.updateDraft draft

        ClickDeleteDraft draft ->
            Api.deleteDraft draft model

        OnFetchCreatedAccount account ->
            remoteAccount account model
                |> resetForm
                |> withNoCommand

        OnFetchAuth0Token token ->
            remoteAuth0 token model
                |> Api.authGraphCool

        OnFetchGraphCoolToken token ->
            remoteGraphCool token model
                |> Api.fetchUser
                |> andAlso Api.fetchPublicDrafts

        OnFetchUserInfo user ->
            remoteUser user model
                |> resetForm
                |> withCommands
                    [ saveTokens model ]
                |> andAlso reroute

        OnFetchUpdatedDraft web ->
            remoteUpdatedDraft web model
                |> updateDraft web
                |> resetMenu
                |> withCommands
                    [ updateTime ]

        OnFetchCreatedDraft web ->
            updateDraft web model
                |> resetForm
                |> resetMenu
                |> reroute
                |> andAlso
                    (\m -> case m.route of
                           Ok PublicDraftsRoute  ->
                               RemoteData.map (\d -> DraftRoute d.id) web
                                |> RemoteData.map (\r -> [Navigation.newUrl <| path r])
                                |> RemoteData.map (flip withCommands m)
                                |> RemoteData.withDefault (withNoCommand m)
                           _ -> withNoCommand m
                    )

        OnFetchDeletedDraft web ->
            removeDraft web model
                |> resetMenu
                |> withNoCommand

        OnFetchPublicDrafts web ->
            remotePublicDrafts web model
                |> withNoCommand


