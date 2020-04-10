module Main exposing (main)

import Color
import Data.Author as Author
import Date
import DocSidebar
import DocumentSvg
import Element exposing (Element)
import Element.Background
import Element.Border
import Element.Events
import Element.Font as Font
import Element.Region
import Feed
import FontAwesome
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attr
import Index
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Exploration as D
import Json.Encode
import MarkdownRenderer
import Metadata exposing (Metadata)
import MySitemap
import Pages exposing (images, pages)
import Pages.Directory as Directory exposing (Directory)
import Pages.Document
import Pages.ImagePath as ImagePath exposing (ImagePath)
import Pages.Manifest as Manifest
import Pages.Manifest.Category
import Pages.PagePath as PagePath exposing (PagePath)
import Pages.Platform exposing (Page)
import Pages.StaticHttp as StaticHttp
import Palette
import Secrets
import Showcase
import StructuredData


manifest : Manifest.Config Pages.PathKey
manifest =
    { backgroundColor = Just Color.white
    , categories = [ Pages.Manifest.Category.education ]
    , displayMode = Manifest.Standalone
    , orientation = Manifest.Portrait
    , description = "elm-pages - A statically typed site generator."
    , iarcRatingId = Nothing
    , name = "elm-pages docs"
    , themeColor = Just Color.white
    , startUrl = pages.index
    , shortName = Just "elm-pages"
    , sourceIcon = images.iconPng
    }


type alias View =
    ( MarkdownRenderer.TableOfContents, List (Element Msg) )


main : Pages.Platform.Program Model Msg Metadata View
main =
    Pages.Platform.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , documents = [ markdownDocument ]
        , manifest = manifest
        , canonicalSiteUrl = canonicalSiteUrl
        , generateFiles = generateFiles
        , onPageChange = OnPageChange
        , internals = Pages.internals
        }


generateFiles :
    List
        { path : PagePath Pages.PathKey
        , frontmatter : Metadata
        , body : String
        }
    ->
        List
            (Result String
                { path : List String
                , content : String
                }
            )
generateFiles siteMetadata =
    [ Feed.fileToGenerate { siteTagline = siteTagline, siteUrl = canonicalSiteUrl } siteMetadata |> Ok
    , MySitemap.build { siteUrl = canonicalSiteUrl } siteMetadata |> Ok
    ]


markdownDocument : ( String, Pages.Document.DocumentHandler Metadata ( MarkdownRenderer.TableOfContents, List (Element Msg) ) )
markdownDocument =
    Pages.Document.parser
        { extension = "md"
        , metadata = Metadata.decoder
        , body = MarkdownRenderer.view
        }


type alias Model =
    { showMobileMenu : Bool
    }


init :
    Maybe
        { path : PagePath Pages.PathKey
        , query : Maybe String
        , fragment : Maybe String
        }
    -> ( Model, Cmd Msg )
init maybePagePath =
    ( Model False, Cmd.none )


type Msg
    = OnPageChange
        { path : PagePath Pages.PathKey
        , query : Maybe String
        , fragment : Maybe String
        }
    | ToggleMobileMenu


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnPageChange page ->
            ( { model | showMobileMenu = False }, Cmd.none )

        ToggleMobileMenu ->
            ( { model | showMobileMenu = not model.showMobileMenu }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view :
    List ( PagePath Pages.PathKey, Metadata )
    ->
        { path : PagePath Pages.PathKey
        , frontmatter : Metadata
        }
    ->
        StaticHttp.Request
            { view : Model -> View -> { title : String, body : Html Msg }
            , head : List (Head.Tag Pages.PathKey)
            }
view siteMetadata page =
    case page.frontmatter of
        Metadata.Showcase ->
            StaticHttp.map2
                (\stars showcaseData ->
                    { view =
                        \model viewForPage ->
                            { title = "elm-pages blog"
                            , body =
                                Element.column [ Element.width Element.fill ]
                                    [ Element.column [ Element.padding 20, Element.centerX ] [ Showcase.view showcaseData ]
                                    ]
                            }
                                |> wrapBody stars page model
                    , head = head page.path page.frontmatter
                    }
                )
                (StaticHttp.get (Secrets.succeed "https://api.github.com/repos/dillonkearns/elm-pages")
                    (D.field "stargazers_count" D.int)
                )
                Showcase.staticRequest

        _ ->
            StaticHttp.get (Secrets.succeed "https://api.github.com/repos/dillonkearns/elm-pages")
                (D.field "stargazers_count" D.int)
                |> StaticHttp.map
                    (\stars ->
                        { view =
                            \model viewForPage ->
                                pageView stars model siteMetadata page viewForPage
                                    |> wrapBody stars page model
                        , head = head page.path page.frontmatter
                        }
                    )



--let
--    viewFn =
--        case page.frontmatter of
--            Metadata.Page metadata ->
--                StaticHttp.map3
--                    (\elmPagesStars elmPagesStarterStars netlifyStars ->
--                        { view =
--                            \model viewForPage ->
--                                { title = metadata.title
--                                , body =
--                                    "elm-pages ⭐️'s: "
--                                        ++ String.fromInt elmPagesStars
--                                        ++ "\n\nelm-pages-starter ⭐️'s: "
--                                        ++ String.fromInt elmPagesStarterStars
--                                        ++ "\n\nelm-markdown ⭐️'s: "
--                                        ++ String.fromInt netlifyStars
--                                        |> Element.text
--                                        |> wrapBody
--                                }
--                        , head = head page.frontmatter
--                        }
--                    )
--                    (StaticHttp.get (Secrets.succeed "https://api.github.com/repos/dillonkearns/elm-pages")
--                        (D.field "stargazers_count" D.int)
--                    )
--                    (StaticHttp.get (Secrets.succeed "https://api.github.com/repos/dillonkearns/elm-pages-starter")
--                        (D.field "stargazers_count" D.int)
--                    )
--                    (StaticHttp.get (Secrets.succeed "https://api.github.com/repos/dillonkearns/elm-markdown")
--                        (D.field "stargazers_count" D.int)
--                    )
--
--            _ ->
--                    StaticHttp.withData "https://api.github.com/repos/dillonkearns/elm-pages"
--                        (Decode.field "stargazers_count" Decode.int)


pageView :
    Int
    -> Model
    -> List ( PagePath Pages.PathKey, Metadata )
    -> { path : PagePath Pages.PathKey, frontmatter : Metadata }
    -> ( MarkdownRenderer.TableOfContents, List (Element Msg) )
    -> { title : String, body : Element Msg }
pageView stars model siteMetadata page viewForPage =
    case page.frontmatter of
        Metadata.Page metadata ->
            { title = metadata.title
            , body =
                [ Element.column
                    [ Element.padding 50
                    , Element.spacing 60
                    , Element.Region.mainContent
                    ]
                    (Tuple.second viewForPage)
                ]
                    |> Element.textColumn
                        [ Element.width Element.fill
                        ]
            }

        Metadata.Article metadata ->
            { title = metadata.title
            , body =
                Element.column [ Element.width Element.fill ]
                    [ Element.column
                        [ Element.padding 30
                        , Element.spacing 40
                        , Element.Region.mainContent
                        , Element.width (Element.fill |> Element.maximum 800)
                        , Element.centerX
                        ]
                        (Element.column [ Element.spacing 10 ]
                            [ Element.row [ Element.spacing 10 ]
                                [ Author.view [] metadata.author
                                , Element.column [ Element.spacing 10, Element.width Element.fill ]
                                    [ Element.paragraph [ Font.bold, Font.size 24 ]
                                        [ Element.text metadata.author.name
                                        ]
                                    , Element.paragraph [ Font.size 16 ]
                                        [ Element.text metadata.author.bio ]
                                    ]
                                ]
                            ]
                            :: (publishedDateView metadata |> Element.el [ Font.size 16, Font.color (Element.rgba255 0 0 0 0.6) ])
                            :: Palette.blogHeading metadata.title
                            :: articleImageView metadata.image
                            :: Tuple.second viewForPage
                        )
                    ]
            }

        Metadata.Doc metadata ->
            { title = metadata.title
            , body =
                [ Element.row []
                    [ DocSidebar.view page.path siteMetadata
                        |> Element.el [ Element.width (Element.fillPortion 2), Element.alignTop, Element.height Element.fill ]
                    , Element.column [ Element.width (Element.fillPortion 8), Element.padding 35, Element.spacing 15 ]
                        [ Palette.heading 1 [ Element.text metadata.title ]
                        , Element.column [ Element.spacing 20 ]
                            [ tocView (Tuple.first viewForPage)
                            , Element.column
                                [ Element.padding 50
                                , Element.spacing 30
                                , Element.Region.mainContent
                                ]
                                (Tuple.second viewForPage)
                            ]
                        ]
                    ]
                ]
                    |> Element.textColumn
                        [ Element.width Element.fill
                        , Element.height Element.fill
                        ]
            }

        Metadata.Author author ->
            { title = author.name
            , body =
                Element.column
                    [ Element.width Element.fill
                    ]
                    [ Element.column
                        [ Element.padding 30
                        , Element.spacing 20
                        , Element.Region.mainContent
                        , Element.width (Element.fill |> Element.maximum 800)
                        , Element.centerX
                        ]
                        [ Palette.blogHeading author.name
                        , Author.view [] author
                        , Element.paragraph [ Element.centerX, Font.center ] (Tuple.second viewForPage)
                        ]
                    ]
            }

        Metadata.BlogIndex ->
            { title = "elm-pages blog"
            , body =
                Element.column [ Element.width Element.fill ]
                    [ Element.column [ Element.padding 20, Element.centerX ] [ Index.view siteMetadata ]
                    ]
            }

        Metadata.Showcase ->
            { title = "elm-pages blog"
            , body =
                Element.column [ Element.width Element.fill ]
                    [--, Element.column [ Element.padding 20, Element.centerX ] [ Showcase.view siteMetadata ]
                    ]
            }


wrapBody : Int -> { a | path : PagePath Pages.PathKey } -> Model -> { c | body : Element Msg, title : String } -> { body : Html Msg, title : String }
wrapBody stars page model record =
    { body =
        (if model.showMobileMenu then
            Element.column
                [ Element.width Element.fill
                , Element.padding 20
                ]
                [ Element.row [ Element.width Element.fill, Element.spaceEvenly ]
                    [ logoLinkMobile
                    , FontAwesome.styledIcon "fas fa-bars" [ Element.Events.onClick ToggleMobileMenu ]
                    ]
                , Element.column [ Element.centerX, Element.spacing 20 ]
                    (navbarLinks stars page.path)
                ]

         else
            Element.column [ Element.width Element.fill ]
                [ header stars page.path
                , record.body
                ]
        )
            |> Element.layout
                [ Element.width Element.fill
                , Font.size 20
                , Font.family [ Font.typeface "Roboto" ]
                , Font.color (Element.rgba255 0 0 0 0.8)
                ]
    , title = record.title
    }


articleImageView : ImagePath Pages.PathKey -> Element msg
articleImageView articleImage =
    Element.image [ Element.width Element.fill ]
        { src = ImagePath.toString articleImage
        , description = "Article cover photo"
        }


header : Int -> PagePath Pages.PathKey -> Element Msg
header stars currentPath =
    Element.column [ Element.width Element.fill ]
        [ responsiveHeader
        , Element.column
            [ Element.width Element.fill
            , Element.htmlAttribute (Attr.class "responsive-desktop")
            ]
            [ Element.el
                [ Element.height (Element.px 4)
                , Element.width Element.fill
                , Element.Background.gradient
                    { angle = 0.2
                    , steps =
                        [ Element.rgb255 0 242 96
                        , Element.rgb255 5 117 230
                        ]
                    }
                ]
                Element.none
            , Element.row
                [ Element.paddingXY 25 4
                , Element.spaceEvenly
                , Element.width Element.fill
                , Element.Region.navigation
                , Element.Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
                , Element.Border.color (Element.rgba255 40 80 40 0.4)
                ]
                [ logoLink
                , Element.row [ Element.spacing 15 ] (navbarLinks stars currentPath)
                ]
            ]
        ]


logoLink =
    Element.link []
        { url = "/"
        , label =
            Element.row
                [ Font.size 30
                , Element.spacing 16
                , Element.htmlAttribute (Attr.class "navbar-title")
                ]
                [ DocumentSvg.view
                , Element.text "elm-pages"
                ]
        }


logoLinkMobile =
    Element.link []
        { url = "/"
        , label =
            Element.row
                [ Font.size 30
                , Element.spacing 16
                , Element.htmlAttribute (Attr.class "navbar-title")
                ]
                [ Element.text "elm-pages"
                ]
        }


navbarLinks stars currentPath =
    [ elmDocsLink
    , githubRepoLink stars
    , highlightableLink currentPath pages.docs.directory "Docs"
    , highlightableLink currentPath pages.showcase.directory "Showcase"
    , highlightableLink currentPath pages.blog.directory "Blog"
    ]


responsiveHeader =
    Element.row
        [ Element.width Element.fill
        , Element.spaceEvenly
        , Element.htmlAttribute (Attr.class "responsive-mobile")
        , Element.width Element.fill
        , Element.padding 20
        ]
        [ logoLinkMobile
        , FontAwesome.icon "fas fa-bars" |> Element.el [ Element.alignRight, Element.Events.onClick ToggleMobileMenu ]
        ]


highlightableLink :
    PagePath Pages.PathKey
    -> Directory Pages.PathKey Directory.WithIndex
    -> String
    -> Element msg
highlightableLink currentPath linkDirectory displayName =
    let
        isHighlighted =
            currentPath |> Directory.includes linkDirectory
    in
    Element.link
        (if isHighlighted then
            [ Font.underline
            , Font.color Palette.color.primary
            ]

         else
            []
        )
        { url = linkDirectory |> Directory.indexPath |> PagePath.toString
        , label = Element.text displayName
        }


commonHeadTags : List (Head.Tag Pages.PathKey)
commonHeadTags =
    [ Head.rssLink "/blog/feed.xml"
    , Head.sitemapLink "/sitemap.xml"
    ]


{-| <https://developer.twitter.com/en/docs/tweets/optimize-with-cards/overview/abouts-cards>
<https://htmlhead.dev>
<https://html.spec.whatwg.org/multipage/semantics.html#standard-metadata-names>
<https://ogp.me/>
-}
head : PagePath Pages.PathKey -> Metadata -> List (Head.Tag Pages.PathKey)
head currentPath metadata =
    commonHeadTags
        ++ (case metadata of
                Metadata.Page meta ->
                    Seo.summary
                        { canonicalUrlOverride = Nothing
                        , siteName = "elm-pages"
                        , image =
                            { url = images.iconPng
                            , alt = "elm-pages logo"
                            , dimensions = Nothing
                            , mimeType = Nothing
                            }
                        , description = siteTagline
                        , locale = Nothing
                        , title = meta.title
                        }
                        |> Seo.website

                Metadata.Doc meta ->
                    Seo.summary
                        { canonicalUrlOverride = Nothing
                        , siteName = "elm-pages"
                        , image =
                            { url = images.iconPng
                            , alt = "elm pages logo"
                            , dimensions = Nothing
                            , mimeType = Nothing
                            }
                        , locale = Nothing
                        , description = siteTagline
                        , title = meta.title
                        }
                        |> Seo.website

                Metadata.Article meta ->
                    Head.structuredData
                        (StructuredData.article
                            { title = meta.title
                            , description = meta.description
                            , url = canonicalSiteUrl ++ "/" ++ PagePath.toString currentPath
                            , datePublished = Date.toIsoString meta.published
                            }
                        )
                        :: (Seo.summaryLarge
                                { canonicalUrlOverride = Nothing
                                , siteName = "elm-pages"
                                , image =
                                    { url = meta.image
                                    , alt = meta.description
                                    , dimensions = Nothing
                                    , mimeType = Nothing
                                    }
                                , description = meta.description
                                , locale = Nothing
                                , title = meta.title
                                }
                                |> Seo.article
                                    { tags = []
                                    , section = Nothing
                                    , publishedTime = Just (Date.toIsoString meta.published)
                                    , modifiedTime = Nothing
                                    , expirationTime = Nothing
                                    }
                           )

                Metadata.Author meta ->
                    let
                        ( firstName, lastName ) =
                            case meta.name |> String.split " " of
                                [ first, last ] ->
                                    ( first, last )

                                [ first, middle, last ] ->
                                    ( first ++ " " ++ middle, last )

                                [] ->
                                    ( "", "" )

                                _ ->
                                    ( meta.name, "" )
                    in
                    Seo.summary
                        { canonicalUrlOverride = Nothing
                        , siteName = "elm-pages"
                        , image =
                            { url = meta.avatar
                            , alt = meta.name ++ "'s elm-pages articles."
                            , dimensions = Nothing
                            , mimeType = Nothing
                            }
                        , description = meta.bio
                        , locale = Nothing
                        , title = meta.name ++ "'s elm-pages articles."
                        }
                        |> Seo.profile
                            { firstName = firstName
                            , lastName = lastName
                            , username = Nothing
                            }

                Metadata.BlogIndex ->
                    Seo.summary
                        { canonicalUrlOverride = Nothing
                        , siteName = "elm-pages"
                        , image =
                            { url = images.iconPng
                            , alt = "elm-pages logo"
                            , dimensions = Nothing
                            , mimeType = Nothing
                            }
                        , description = siteTagline
                        , locale = Nothing
                        , title = "elm-pages blog"
                        }
                        |> Seo.website

                Metadata.Showcase ->
                    Seo.summary
                        { canonicalUrlOverride = Nothing
                        , siteName = "elm-pages"
                        , image =
                            { url = images.iconPng
                            , alt = "elm-pages logo"
                            , dimensions = Nothing
                            , mimeType = Nothing
                            }
                        , description = "See some neat sites built using elm-pages! (Or submit yours!)"
                        , locale = Nothing
                        , title = "elm-pages sites showcase"
                        }
                        |> Seo.website
           )


canonicalSiteUrl : String
canonicalSiteUrl =
    "https://elm-pages.com"


siteTagline : String
siteTagline =
    "A statically typed site generator - elm-pages"


tocView : MarkdownRenderer.TableOfContents -> Element msg
tocView toc =
    Element.column [ Element.alignTop, Element.spacing 20 ]
        [ Element.el [ Font.bold, Font.size 22 ] (Element.text "Table of Contents")
        , Element.column [ Element.spacing 10 ]
            (toc
                |> List.map
                    (\heading ->
                        Element.link [ Font.color (Element.rgb255 100 100 100) ]
                            { url = "#" ++ heading.anchorId
                            , label = Element.text heading.name
                            }
                    )
            )
        ]


publishedDateView metadata =
    Element.text
        (metadata.published
            |> Date.format "MMMM ddd, yyyy"
        )


githubRepoLink : Int -> Element msg
githubRepoLink starCount =
    Element.newTabLink []
        { url = "https://github.com/dillonkearns/elm-pages"
        , label =
            Element.row [ Element.spacing 5 ]
                [ Element.image
                    [ Element.width (Element.px 22)
                    , Font.color Palette.color.primary
                    ]
                    { src = ImagePath.toString Pages.images.github, description = "Github repo" }
                , Element.text <| String.fromInt starCount
                ]
        }


elmDocsLink : Element msg
elmDocsLink =
    Element.newTabLink []
        { url = "https://package.elm-lang.org/packages/dillonkearns/elm-pages/latest/"
        , label =
            Element.image
                [ Element.width (Element.px 22)
                , Font.color Palette.color.primary
                ]
                { src = ImagePath.toString Pages.images.elmLogo, description = "Elm Package Docs" }
        }
