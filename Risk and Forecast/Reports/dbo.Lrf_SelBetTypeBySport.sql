ALTER PROCEDURE [dbo].[Lrf_SelBetTypeBySport]
	@LicenseeID int
	,@SportList nvarchar(4000)
AS 
/*
Created: 20131010@Don
Task : Get list of bettype by sports
DB: DBLIC/bodb_Licensee

Revisions:
   
Param's Explanation:
	
*/
/*SET @LicenseeID = 1
DECLARE @SportList nvarchar(4000)
SET @SportList = 
N'
<products>
<product ID="0" Sport="1,2,3,4"> 
</product>
<product ID="2" Sport=""> 
</product>
<product ID="3" Sport=""> 
</product>
</products>'*/

DECLARE @iDoc int

EXEC sp_xml_preparedocument @iDoc OUTPUT, @SportList

SELECT *
INTO #input
FROM OPENXML (@iDoc, '/products/product',1) WITH(ID tinyint, Sport nvarchar(128))

EXEC sp_xml_removedocument @iDoc

DECLARE @Bettype TABLE (
	BettypeID tinyint
	,BettypeName nvarchar(50)
)

IF EXISTS(SELECT * FROM #input WHERE ID = 0 AND ISNULL(Sport,'') <> '')
BEGIN

	INSERT INTO @Bettype
		SELECT typeid, typenamee
		FROM bodb02.dbo.bettype WITH(NOLOCK)
		WHERE (typeid < 31 OR (typeid BETWEEN 121 AND 999))

END

IF EXISTS(SELECT * FROM #input WHERE ID > 0)
BEGIN

	INSERT INTO @Bettype
		SELECT typeid, N'NG - ' + typenamee
		FROM bodb02.dbo.bettype WITH(NOLOCK)
		WHERE (typeid BETWEEN 81 AND 120)

END

DROP TABLE #input

SELECT * FROM @Bettype

GO
GRANT EXECUTE ON [dbo].[Lrf_SelBetTypeBySport] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SelBetTypeBySport] TO [vnteam] 