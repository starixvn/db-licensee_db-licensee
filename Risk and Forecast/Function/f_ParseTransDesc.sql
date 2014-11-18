ALTER FUNCTION [dbo].[f_ParseTransDesc]
(
	@TransDesc NVARCHAR(300)
	, @BetType INT = -1
)  
RETURNS @OutputTable TABLE(GameId INT, ChoiceId VARCHAR(10))
AS  
/*
	Created: 20140306@Patrick
	Task : Get GameId and ChoiceId from TransDesc
			- If GameId contains of character then set to -1
			- If TransDesc wrong format then return null

	DB: DBACC/bodb02, DBAGE/bodb02, DBARC/bodb_archive, DBAGE/bodb_Age
	Revisions:
		
	Paramters Explanation:
		@TransDesc = 'betChoice=[GaneId],[ChoiceId];referID='
			Ex: betChoice=1704525,3;referID=

*/

BEGIN 

	IF @TransDesc IS NULL OR @TransDesc = ''
		RETURN
	IF @BetType < 1501 OR @BetType > 1599
		RETURN
	
	DECLARE @Separate CHAR(1) = ','
	
	SET @TransDesc = REPLACE(SUBSTRING(@TransDesc, 0, CHARINDEX(';', @TransDesc)), 'betChoice=', '')
	IF @TransDesc = ''
		RETURN

	DECLARE @GameId VARCHAR(50), @ChoiceId VARCHAR(10)

	;WITH Pieces([Index], Start, [Stop])
	AS 
	(
		SELECT 1, 1, CHARINDEX(@Separate, @TransDesc)

		UNION ALL
		
		SELECT [Index] + 1, [Stop] + 1, CHARINDEX(@Separate, @TransDesc, [Stop] + 1)
		FROM Pieces	WHERE [Stop] > 0
	)
	
	SELECT @GameId = (SELECT SUBSTRING(@TransDesc, Start, CASE WHEN [Stop] > 0 THEN [Stop] - Start ELSE 300 END) FROM Pieces WHERE [Index] = 1)
		, @ChoiceId = (SELECT SUBSTRING(@TransDesc, Start, CASE WHEN [Stop] > 0 THEN [Stop] - Start ELSE 300 END) FROM Pieces WHERE [Index] = 2)
	FROM Pieces

	INSERT INTO @OutputTable(GameId, ChoiceId)
	(
		SELECT CASE WHEN ISNUMERIC(@GameId) = 1 THEN CAST(@GameId AS INT) ELSE -1 END, @ChoiceId
	)
	RETURN
END
GO
GRANT VIEW DEFINITION ON [dbo].[f_ParseTransDesc] TO [vnteam] AS [dbo]
