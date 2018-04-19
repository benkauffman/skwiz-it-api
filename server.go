package main

import (
	"./handler"
	"./middleware"

	"log"
	"net/http"

	"github.com/codegangsta/negroni"
	"github.com/gorilla/handlers"
	"github.com/gorilla/mux"
)

func main() {
	listen := "0.0.0.0:3000"

	log.Printf("Starting server and listening on %s", listen)

	router := mux.NewRouter().StrictSlash(true)

	router.HandleFunc("/api/health", handler.HealthCheck)

	privateBase := mux.NewRouter()
	router.PathPrefix("/api/v1/private").Handler(negroni.New(
		negroni.NewLogger(),
		negroni.NewRecovery(),
		negroni.HandlerFunc(middleware.UserAuthMiddleware),
		negroni.Wrap(privateBase),
	))
	private := privateBase.PathPrefix("/api/v1/private").Subrouter()
	private.Methods("GET").Path("/section/type").HandlerFunc(handler.GetSectionType)
	private.Methods("POST").Path("/section/{type}").HandlerFunc(handler.SaveSection)
	private.Methods("GET").Path("/drawings").HandlerFunc(handler.GetUserDrawings)

	publicBase := mux.NewRouter()
	router.PathPrefix("/api/v1/public").Handler(negroni.New(
		negroni.NewLogger(),
		negroni.NewRecovery(),
		negroni.Wrap(publicBase),
	))
	public := publicBase.PathPrefix("/api/v1/public").Subrouter()
	public.Methods("POST").Path("/register").HandlerFunc(handler.RegisterUser)
	public.Methods("GET").Path("/drawing/{id}").HandlerFunc(handler.GetDrawing)
	public.Methods("GET").Path("/drawings").HandlerFunc(handler.GetDrawings)

	allowedHeaders := handlers.AllowedHeaders([]string{"X-App-User", "Content-Type", "Accept"})
	allowedOrigins := handlers.AllowedOrigins([]string{"*"})
	allowedMethods := handlers.AllowedMethods([]string{"GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS"})

	log.Fatal(http.ListenAndServe(listen, handlers.CORS(allowedHeaders, allowedOrigins, allowedMethods)(router)))

}
