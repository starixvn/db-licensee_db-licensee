ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Main]
	@strCustID VARCHAR(MAX),
	@SBComm DECIMAL(9,8) ,
	@NGComm DECIMAL(9,8)=0,	
	@RacingComm DECIMAL(9,8)=0,
	@IsUpdateNG BIT = 0,
	@IsUpdateRacing BIT = 0
AS
/*
Created: 20120907@Viet
Task : Update Licensee's players commission in DBTRANS
DB: DBTRANS.bodb02
Original: 

Revisions:
	
   
Param's Explanation:

*/

BEGIN	

	DECLARE @res AS TABLE (custid INT, isfinished bit)
	DECLARE @splitter CHAR(1), @string VARCHAR(MAX)

	SELECT @splitter = ',', @string = RTRIM(LTRIM(@strCustID))

	IF SUBSTRING (@string, LEN (@string), 1) <> @splitter
		  SET @string= @string+@splitter

	DECLARE @START INT, @word VARCHAR(4000), @CHARINDEX INT, @i INT
	SET @i=1
	SET @START=1
	SET @CHARINDEX= CHARINDEX( @splitter, @string, @START)
	WHILE (@CHARINDEX <> 0)BEGIN
		SET @word= SUBSTRING( @string, @START, @CHARINDEX - @START)
		SET @START= @CHARINDEX +1
		SET @CHARINDEX= CHARINDEX( @splitter, @string, @START)
		INSERT INTO @res(custid, isfinished)  VALUES(CAST(@word AS INT), 0)
		SET @i=@i+1
	END
	
	declare @ids varchar(max), @rowcnt int

	while (1=1)
	begin
		select @ids = ''
		
		update TOP (500) @res
		set @ids = @ids + case @ids when '' then '' else ',' end + cast(custid as varchar(12))
			,isfinished = 1		
		where isfinished = 0
		
		select @rowcnt = @@rowcount	

		EXEC [Acc_ExecRep_02] 
			@ids = @ids
			,@SBComm = @SBComm
			,@NGComm = @NGComm
			,@RacingComm = @RacingComm
			,@IsUpdateNG = @IsUpdateNG
			,@IsUpdateRacing = @IsUpdateRacing
		
		if @rowcnt < 500 RETURN
		WAITFOR DELAY '00:00:02'
	end	
	
END

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMemberComm_Main] TO [Dot_Member] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMemberComm_Main] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMemberComm_Main] TO [bodbLicenseeNet] AS [dbo] 