USE bodb_licensee
GO

-- Need temporary table [dontest] with columns (tablename varchar(30), hasidentitycolumn bit)
DECLARE @sql VARCHAR(MAX) = ''
SELECT 
	@sql		=	@sql + 
					'TRUNCATE TABLE bodb_Licensee.dbo.' + tablename + char(13) +
					CASE hasidentitycolumn
						WHEN CONVERT(BIT, 1) THEN 'SET IDENTITY_INSERT bodb_Licensee.dbo.' + tablename + ' ON'
						ELSE ''
					END + char(13) +
					'INSERT INTO bodb_Licensee.dbo.' + tablename + '(' + SUBSTRING(c.columnslist, 1, LEN(c.columnslist) - 1) + ')' + char(13) +
					'SELECT ' + SUBSTRING(c.columnslist, 1, LEN(c.columnslist) - 1) + ' FROM ActiveServer.bodb_Licensee.dbo.' + tablename + ' WITH(NOLOCK)' + char(13) +
					CASE hasidentitycolumn
						WHEN CONVERT(BIT, 1) THEN 'SET IDENTITY_INSERT bodb_Licensee.dbo.' + tablename + ' OFF'
						ELSE ''
					END + char(13) + '---------------------------' + char(13)
FROM dbo.dontest d
	CROSS APPLY (SELECT name + ',' FROM sys.columns WHERE object_id = object_id(d.tablename) FOR XML PATH('')) c(columnslist)
--WHERE d.tablename = 'OA_UserLicensees'
	

SET @sql = REPLACE(@sql, 'ActiveServer', 'DBLIC')

PRINT @sql