################################################################################################################
#Write a program that loops from 1 to 40 and prints the following:
#If the number is a multiple of 2, print "DO"
#If the number is a multiple of 3, print "RE"
#If the number is a multiple of 5, print "MI"
#If the number is a combination, print the combination (ex: for 6, print "DORE")
#If the number is not a multiple of 2, 3 or 5, print the number
#You may use any of the top-10 languages in the TIOBE Index (http://www.tiobe.com/tiobe-index/). Please keep
#things simple:
#Use console input and output (standard input/output)
#Use built-in data structures - don't use a database, XML files, etc.
################################################################################################################

#create counter variable for loop
cnt = 1

#print('Begin Loop')

#start for loop
while cnt <= 40:
  #check if number is not factor of 2,3,5
  if cnt%2 != 0 and cnt%3 != 0 and cnt%5 != 0:
      print(cnt)
  #check if number is a factor of 2,3,5
  elif cnt%2 == 0 and cnt%3 == 0 and cnt%5 == 0:
    print('DOREMI')
  #check if number is a factor of 2 and 3  
  elif cnt%2 == 0 and cnt%3 == 0:
    print('DORE')
  #check if number is a factor of 3 and 5  
  elif cnt%3 == 0 and cnt%5 == 0:
    print('REMI')
  #check if number is a factor of 2 and 5  
  elif cnt%2 == 0 and cnt%5 == 0:
    print('DOMI')
  #check if number is a factor of 2 only
  elif cnt%2 == 0:
    print('DO')
  #check if number is a factor of 3 only  
  elif cnt%3 == 0:
    print('RE')
  #check if number is a factor of 5 only  
  elif cnt%5 == 0:
    print('MI')
  #Loop completed, increment counter variable by 1  
  cnt+=1

#Loop exited  
print('Loop finished')
