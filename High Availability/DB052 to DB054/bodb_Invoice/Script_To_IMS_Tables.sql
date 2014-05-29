USE bodb_Invoice
GO

-- Need temporary table [dontest] with columns (tablename varchar(30), hasidentitycolumn bit)
DECLARE @sql VARCHAR(4000) = ''
DECLARE @columns VARCHAR(512) = ''
DECLARE @columns2 VARCHAR(512) = ''
SELECT 
	@sql		=	@sql + 
					'TRUNCATE TABLE bodb_Invoice.dbo.' + tablename + char(13) +
					CASE hasidentitycolumn
						WHEN CONVERT(BIT, 1) THEN 'SET IDENTITY_INSERT bodb_Invoice.dbo.' + tablename + ' ON'
						ELSE ''
					END + char(13) +
					'INSERT INTO bodb_Invoice.dbo.' + tablename + '(' + SUBSTRING(c.columnslist, 1, LEN(c.columnslist) - 1) + ')' + char(13) +
					'SELECT ' + SUBSTRING(c.columnslist, 1, LEN(c.columnslist) - 1) + ' FROM ActiveServer.bodb_Invoice.dbo.' + tablename + ' WITH(NOLOCK)' + char(13) +
					CASE hasidentitycolumn
						WHEN CONVERT(BIT, 1) THEN 'SET IDENTITY_INSERT bodb_Invoice.dbo.' + tablename + ' OFF'
						ELSE ''
					END + char(13) + '---------------------------' + char(13)
FROM bodb_licensee.dbo.dontest d
	CROSS APPLY (SELECT name + ',' FROM sys.columns WHERE object_id = object_id(tablename) FOR XML PATH('')) c(columnslist)
	

SET @sql = REPLACE(@sql, 'ActiveServer', 'DBLIC')

PRINT @sql