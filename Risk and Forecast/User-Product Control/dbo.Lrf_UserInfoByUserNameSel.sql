/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_UserInfoByUserNameSel]
    @UserName   VARCHAR(50),
    @AgentList  VARCHAR(MAX)
AS
/*  Created: Walter  
	Date: 2019-11-28
    Task : Get CustId by UserName
    DB: DBEXT-bodb02 
   
    Revisions:
		- 20191128@Walter: Initialize SP [RedmineID: #124316]

	Param's Explanation:  
	  + @UserName: UserName of Customer

	Sample:
    exec Lrf_UserInfoByUserNameSel 
	@UserName='simo2912',
	@AgentList='<ROOT><Agent AgentId="1015423" Currency="9"/></ROOT>'
*/
BEGIN
    DECLARE @TempAg TABLE (CustId INT PRIMARY KEY, Currency INT)
    -------- Get AgentList 	
    DECLARE @DocHandler INT

    BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
        SELECT AgentId, Currency
        FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		RETURN
	END CATCH
    -------End Get AgentList

    SET @UserName = LTRIM(RTRIM(ISNULL(@UserName, '')))
    IF @UserName <> ''
	BEGIN
        SELECT c.custid
        FROM
            dbo.Customer  c WITH (NOLOCK)
        WHERE
			EXISTS(
                    SELECT TOP 1 1
                    FROM @TempAg t
                    WHERE c.recommend = t.CustId
            )
            AND (
				c.username = @UserName -- SystemId
                OR SUBSTRING(c.username2,  CHARINDEX('$',c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) = @UserName --UserName
			) 
            AND c.roleid = 1
    END
END
 