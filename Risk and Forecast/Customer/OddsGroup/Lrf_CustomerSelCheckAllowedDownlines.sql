/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_lap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_CustomerSelCheckAllowedDownlines]    
 @custid   INT = 0      
 ,@Language  VARCHAR(2) = 'E'    
 ,@ErrCode  INT = 0 OUTPUT    
 ,@ErrMsg  NVARCHAR(200) = '' OUTPUT      
AS      
/*    
	Created: 20241101@Johnson	
	Task : Check Allowed downlines during peak hour at weekend for Licensee 
	DB: DBCUST/CUSTDB          
	  
	Revisions:         
	  - 20241101@Johnson: Check allowed downlines when update OddsGroup for licensee [redmine:#199306]
	Param's Explanation: 
		
*/    
    
BEGIN      
	SET NOCOUNT ON    
	 
	DECLARE @LimitDownlinesMin INT,   --Peak hours  
		@LimitDownlinesMax INT,    -- Normal   
		@LimitDownlines INT,    
		@TotalDownlines INT,
		@RoleID		  INT   
	 
	SET @LimitDownlinesMin = 40000   
	SET @LimitDownlinesMax = 1000000

	--GET TOTALDOWNLINE    
	SET @TotalDownlines=1  

	SELECT @RoleID=RoleID FROM Customer WITH(NOLOCK) WHERE Custid=@custid
	
	IF(@RoleID=4)     
		SELECT  @TotalDownlines = count(1)     
		FROM Custinfo WITH (NOLOCK)    
		WHERE srecommend=@custID     

	IF(@RoleID=2)     
		SELECT  @TotalDownlines = count(1)     
		FROM Custinfo WITH (NOLOCK)    
		WHERE recommend=@custID

	SELECT  @LimitDownlines = CASE  WHEN  datename(weekday, getdate()) in ('Saturday','Sunday' ) and 
           datepart(hour, getdate()) between 7 and  14 --Weekend's peak hour, from 7PM - 2AM (GMT+8)    
	THEN  @LimitDownlinesMin    
	ELSE @LimitDownlinesMax  END 

	IF @TotalDownlines >  @LimitDownlines    
	 BEGIN         
	  SELECT @ErrMsg= CASE @Language WHEN 'E' THEN 'This function cannot be performed at this time as it may affect the performance of the whole system. Please contact IT for further assistance.'  
			  ELSE [dbo].[f_Get_MsgNamebyMsgID](90028,@Language) END  
		,@ErrCode = 100         
	 END   	
END