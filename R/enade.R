get_catalog_enade <-
	function( data_name = "enade" , output_dir , ... ){

		inep_portal <- "http://portal.inep.gov.br/microdados"

		w <- rvest::html_attr( rvest::html_nodes( xml2::read_html( inep_portal ) , "a" ) , "href" )
		
		these_links <- w[ grep( "enade(.*)zip$|enade(.*)rar$" , basename( w ) , ignore.case = TRUE ) ]

		these_links <- gsub( "http://download.inep.gov.br/microdados/Enade_Microdados/microdados_enade_2005.zip http://download.inep.gov.br/microdados/Enade_Microdados/microdados_enade_2006.zip" , "http://download.inep.gov.br/microdados/Enade_Microdados/microdados_enade_2006.zip" , these_links , fixed = TRUE )
		
		enade_years <- substr( gsub( "[^0-9]" , "" , these_links ) , 1 , 4 )

		catalog <-
			data.frame(
				year = enade_years ,
				full_url = these_links ,
				output_filename = paste0( output_dir , "/" , enade_years , " main.rds" ) ,
				output_folder = paste0( output_dir , "/" , enade_years , "/" ) ,
				stringsAsFactors = FALSE
			)

		catalog

	}


lodown_enade <-
	function( data_name = "enade" , catalog , path_to_7z = if( .Platform$OS.type != 'windows' ) '7za' else normalizePath( "C:/Program Files/7-zip/7z.exe" ) , ... ){

		if( system( paste0( '"' , path_to_7z , '" -h' ) , show.output.on.console = FALSE ) != 0 ) stop( paste0( "you need to install 7-zip.  if you already have it, include a parameter like path_to_7z='" , path_to_7z , "'" ) )

		tf <- tempfile()
		
		for ( i in seq_len( nrow( catalog ) ) ){

			# download the file
			cachaca( catalog[ i , "full_url" ] , tf , mode = 'wb' )

			dos.command <- paste0( '"' , path_to_7z , '" x "' , tf , '" -o"' , normalizePath( catalog[ i , "output_folder" ] ) , '"' )

			system( dos.command )

			z <- unique( list.files( catalog[ i , 'output_folder' ] , recursive = TRUE , full.names = TRUE  ) )

			zf <- grep( "\\.zip|\\.ZIP" , list.files( catalog[ i , 'output_folder' ] , recursive = TRUE , full.names = TRUE  ) , value = TRUE )

			if( length( zf ) > 0 ){

				dos.command <- paste0( '"' , path_to_7z , '" x "' , zf , '" -o"' , normalizePath( catalog[ i , "output_folder" ] ) , '"' )

				system( dos.command )

				z <- unique( c( z , list.files( catalog[ i , 'output_folder' ] , recursive = TRUE , full.names = TRUE  ) ) )

			}

			rfi <- grep( "\\.rar|\\.RAR" , z , value = TRUE )

			if( length( rfi ) > 0 ) {

				dos.command <- paste0( '"' , path_to_7z , '" x "' , rfi , '" -o"' , normalizePath( catalog[ i , "output_folder" ] ) , '"' )
				
				system( dos.command )

				z <- unique( c( z , list.files( catalog[ i , 'output_folder' ] , recursive = TRUE , full.names = TRUE  ) ) )

			}

			csvfile <- grep( "\\.csv|\\.CSV" , z , value = TRUE )

			# remove duplicated basenames
			csvfile <- csvfile[ !duplicated( basename( csvfile ) ) ]
			
			stopifnot( length( csvfile ) == 1 )

			tablename <- tolower( gsub( "\\.(.*)" , "" , basename( csvfile ) ) )

			x <- data.frame( readr::read_delim( csvfile , delim = ";" ) )
			
			names( x ) <- tolower( names( x ) )
			
			stopifnot( R.utils::countLines( csvfile ) == nrow( x ) + 1 )

			saveRDS( x , catalog[ i , 'output_filename' ] )
			
			catalog[ i , 'case_count' ] <- nrow( x )
		
			# delete the temporary files?  or move some docs to a save folder?
			suppressWarnings( file.remove( tf ) )
			
			cat( paste0( data_name , " catalog entry " , i , " of " , nrow( catalog ) , " stored at '" , catalog[ i , 'output_filename' ] , "'\r\n\n" ) )

		}

		catalog

	}
