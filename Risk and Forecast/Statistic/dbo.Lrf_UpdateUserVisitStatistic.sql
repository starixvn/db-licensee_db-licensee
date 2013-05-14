ALTER PROCEDURE [dbo].[Lrf_UpdateUserVisitStatistic]  
    @UserId         INT,
    @Url            NVARCHAR(2000),
    @StatisticDate  DATETIME,
    @VisitCount     INT,
    @UserAgent      NVARCHAR(500)
AS /*  
Created:   
Task : Update User Visit Statistic 
DB: DB052.bodb_Licensee 
Original:
Revisions:  
 	 
   
   
Param's Explanation:   

*/  
SET NOCOUNT ON  
DECLARE @FunctionId INT 
DECLARE @StatisticId INT 


SELECT TOP(1) @FunctionId = FunctionId
FROM   Functions f WITH (NOLOCK)
WHERE  @Url LIKE'%' + f.url + '%' and f.Url is NOT null and len(f.Url)>0

SELECT @StatisticId = statisticid 
FROM   [dbo].[UserStatistic] WITH(nolock) 
WHERE  userid = @UserId 
    AND FunctionId = @FunctionId 
	AND UserAgent=@UserAgent
    AND statisticdate = @StatisticDate 

IF @StatisticId IS NULL 
BEGIN 
    INSERT INTO [dbo].[UserStatistic] 
                (
                 userid, 
				functionid,
                 url, 
                 statisticdate, 
                 visitcount, 
                 useragent) 
    VALUES     (
                @UserId, 
				@FunctionId,
                @Url, 
                @StatisticDate, 
                @VisitCount, 
                @UserAgent) 
END 
ELSE 
BEGIN 
    UPDATE [dbo].[UserStatistic] WITH (ROWLOCK,UPDLOCK)
    SET    visitcount = visitcount + @VisitCount 
    WHERE  statisticid = @StatisticId 
END 



GO
GRANT EXECUTE ON [dbo].[Lrf_UpdateUserVisitStatistic] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_UpdateUserVisitStatistic] TO [VNTeam]
GO


 