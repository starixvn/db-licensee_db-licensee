/*<info serverAlias="DBACC-bodb02,DBEXT-bodb02" executers="" viewers="vnteam" isFunction="1" isNested="0"></info>*/
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

	DB: DBACC/bodb02, DBEXT/bodb02
	Revisions:
		- 20171009@Paul: Parse string if not having referID; Check if string has 'betChoice=' pattern [RedmineID: #84541]
		
	Paramters Explanation:
		Old format: @TransDesc = 'betChoice=[GameId],[ChoiceId];referID='
			Ex: betChoice=1704525,3;referID=

		New format: @TransDesc = 'betChoice=[GameId],[ChoiceId]'
			Ex: betChoice=1704525,3
*/

BEGIN 

	IF @TransDesc IS NULL OR @TransDesc = ''
		RETURN
	IF @BetType < 1501 OR @BetType > 1599
		RETURN
	IF PATINDEX('betChoice=%', @TransDesc) = 0
		RETURN
	
	DECLARE @Separate CHAR(1) = ','
	
	IF PATINDEX('%;referID=%', @TransDesc) > 0
	BEGIN
		SET @TransDesc = REPLACE(SUBSTRING(@TransDesc, 0, CHARINDEX(';', @TransDesc)), 'betChoice=', '')
	END
	ELSE
	BEGIN
		SET @TransDesc = REPLACE(@TransDesc, 'betChoice=', '')
	END

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