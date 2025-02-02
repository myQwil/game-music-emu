#include "Archive_Reader.h"

#ifdef RARDLL

#include <string.h>

static int CALLBACK call_rar( UINT msg, LPARAM UserData, LPARAM P1, LPARAM P2 )
{
	uint8_t **bp = (uint8_t **)UserData;
	uint8_t *addr = (uint8_t *)P1;
	memcpy( *bp, addr, P2 );
	*bp += P2;
	(void) msg;
	return 0;
}

blargg_err_t Rar_Reader::restart( RAROpenArchiveData* data )
{
	if ( rar )
		close();
	rar = RAROpenArchive( data );
	if ( !rar )
		return ERR_RAR_CREATE_HANDLE;
	RARSetCallback( rar, call_rar, (LPARAM)&bp );
	return 0;
}

blargg_err_t Rar_Reader::open( const char* path )
{
	RAROpenArchiveData data;
	memset( &data, 0, sizeof data );
	data.ArcName = (char *)path;
	data.OpenMode = RAR_OM_LIST;

	// determine space needed for the unpacked size and file count.
	blargg_err_t err;
	if ( (err = restart( &data )) )
		return err;
	while ( RARReadHeader( rar, &head ) == ERAR_SUCCESS )
	{
		RARProcessFile( rar, RAR_SKIP, nullptr, nullptr );
		count_++, size_ += head.UnpSize;
	}

	// prepare for extraction
	data.OpenMode = RAR_OM_EXTRACT;
	return restart( &data );
}

blargg_err_t Rar_Reader::read( void* p )
{
	bp = p;
	if ( RARProcessFile( rar, -1, nullptr, nullptr ) != ERAR_SUCCESS )
		return ERR_RAR_PROCESS;
	return 0;
}

#endif // RARDLL
