set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  FUNCTION [dbo].[Lrf_f_GetChoice]
(
	@betteam VARCHAR(50),
	@bettype INT,
	@Langkey VARCHAR(10) = 'en-US'
)
RETURNS NVARCHAR(20)
/*	Created: Henry
	Date: 2010-12-25
	Task: Get betteam by language
	DB: DB05.BODB02, DB052.BODB02, DB06.BODB02
	Original: [f_GetChoice]
	Revision:
	- 20130414@Jim: support multi language
*/
AS
BEGIN
	DECLARE @returnVal NVARCHAR(20)
	
	
	IF @bettype = 14--FGLG
	BEGIN
		DECLARE 
			@HA VARCHAR(1),
			@FGLG VARCHAR(1)
		
		SELECT @HA = LEFT(@betteam, 1)
		SELECT @FGLG = RIGHT(@betteam, 1)
		
		SELECT @returnVal =
			CASE @HA 
				WHEN '1' THEN 
					CASE @Langkey WHEN 'en-US' THEN 'Home'
								  ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200051,@Langkey)
								  END 
				WHEN '2' THEN 
					CASE @Langkey WHEN 'en-US' THEN 'Away' 
								  ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200052,@Langkey)	
								  END 
				ELSE 
					CASE @Langkey WHEN 'en-US' THEN 'No'
								  ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200053,@Langkey)
								  END 
			END			
				+
			CASE @FGLG 
				WHEN '1' THEN 
					CASE @Langkey WHEN 'en-US' THEN 'FG'
								   ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200048,@Langkey)
								   END 
				WHEN '2' THEN
					CASE @Langkey WHEN 'en-US' THEN 'LG'
								  ELSE  [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200049,@Langkey)
								  END				
				ELSE CASE @Langkey WHEN 'en-US'THEN 'Goal'
								   ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200050,@Langkey)
								   END 
			END		
	END
	ELSE IF @bettype = 16 --HTFT
	BEGIN
		DECLARE 
			@home VARCHAR(1),
			@away VARCHAR(1)
		
		SELECT @home = LEFT(@betteam, 1)
		SELECT @away = RIGHT(@betteam, 1)
		
		SELECT @returnVal = 
			CASE @home 
				WHEN '1' THEN CASE @Langkey WHEN 'en-US' THEN  'H' 
											ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200045,@Langkey) 
											END
				WHEN '2' THEN CASE @Langkey WHEN 'en-US' THEN  'A' 
											ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200046,@Langkey) 
											END
				ELSE CASE @Langkey		 WHEN 'en-US' THEN  'D' 
										 ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200047,@Langkey) 
										 END
			END 
			+ CASE @away 
				WHEN '1' THEN CASE @Langkey WHEN 'en-US' THEN 'H'
											 ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200045,@Langkey) 
											 END
				WHEN '2' THEN CASE @Langkey WHEN 'en-US' THEN 'A' 
											ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200046,@Langkey) 
											END
				ELSE CASE @Langkey WHEN 'en-US' THEN 'D' 
									ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200047,@Langkey) 
									END
			END
	END
	ELSE
		SELECT @returnVal = @betteam
	
	RETURN @returnVal
		
END

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_f_GetChoice] TO [vnteam]
